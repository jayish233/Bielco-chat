import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/format.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/relay_palette.dart';
import '../../../../core/theme/tokens.dart';
import '../../domain/message.dart';

/// Signed URL for a private attachment (cached by the repository).
final attachmentUrlProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, path) => ref.watch(messageRepositoryProvider).attachmentUrl(path),
);

/// Photo in a bubble. Uses the local bytes while the message is uploading.
class ImageAttachmentView extends ConsumerWidget {
  const ImageAttachmentView({
    super.key,
    required this.message,
    this.maxWidth = 280,
  });

  final Message message;
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, box) => _build(
        context,
        ref,
        box.maxWidth.isFinite && box.maxWidth < maxWidth
            ? box.maxWidth
            : maxWidth,
      ),
    );
  }

  Widget _build(BuildContext context, WidgetRef ref, double width) {
    final a = message.attachment!;
    final p = context.palette;
    final w = a.width ?? 4;
    final h = a.height ?? 3;
    final aspect = (w / h).clamp(0.5, 2.0);
    final height = (width / aspect).clamp(120.0, 360.0);
    final pending = message.pending;

    Widget image;
    if (pending != null) {
      image = Image.memory(pending.bytes, fit: BoxFit.cover);
    } else {
      final url = ref.watch(attachmentUrlProvider(a.path));
      image = url.when(
        data: (u) => Image.network(
          u,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _broken(p),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : ColoredBox(color: p.fillMuted),
        ),
        loading: () => ColoredBox(color: p.fillMuted),
        error: (_, _) => _broken(p),
      );
    }

    final tile = ClipRRect(
      borderRadius: BorderRadius.circular(RelayRadius.xxl),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (message.sendState == SendState.sending)
              const ColoredBox(
                color: Color(0x55000000),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: RelayColors.surface,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (pending != null) return tile;
    return Semantics(
      button: true,
      label: 'Photo. Open full screen',
      child: GestureDetector(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => ImageViewerPage(path: a.path),
          ),
        ),
        child: ExcludeSemantics(child: tile),
      ),
    );
  }

  Widget _broken(RelayPalette p) => ColoredBox(
    color: p.fillMuted,
    child: const Center(child: Icon(Icons.broken_image_outlined)),
  );
}

class ImageViewerPage extends ConsumerWidget {
  const ImageViewerPage({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(attachmentUrlProvider(path));
    return Scaffold(
      backgroundColor: RelayColors.ink,
      appBar: AppBar(
        backgroundColor: RelayColors.ink,
        foregroundColor: RelayColors.surface,
        shape: const Border(),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (url.asData?.value case final u?)
            IconButton(
              tooltip: 'Open original',
              icon: const Icon(Icons.open_in_new),
              onPressed: () =>
                  launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication),
            ),
        ],
      ),
      body: url.when(
        data: (u) => InteractiveViewer(
          maxScale: 5,
          child: Center(child: Image.network(u, fit: BoxFit.contain)),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: RelayColors.surface),
        ),
        error: (_, _) => const Center(
          child: Text(
            'Couldn’t load this photo.',
            style: TextStyle(color: RelayColors.surface),
          ),
        ),
      ),
    );
  }
}

/// File card: extension tile, name, mono "PDF · 2.4 MB". Tap opens it.
class FileAttachmentView extends ConsumerWidget {
  const FileAttachmentView({
    super.key,
    required this.message,
    required this.mine,
  });

  final Message message;
  final bool mine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = message.attachment!;
    final p = context.palette;
    final name = a.name ?? 'File';
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? 'FILE' : name.substring(dot + 1).toUpperCase();
    final fg = mine ? p.onInk : p.ink;
    final muted = mine ? p.onInk.withValues(alpha: 0.7) : p.textSubtle;
    final sending = message.sendState == SendState.sending;

    Future<void> open() async {
      try {
        final url = await ref
            .read(messageRepositoryProvider)
            .attachmentUrl(a.path);
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn’t open this file.')),
          );
        }
      }
    }

    return Semantics(
      button: !sending,
      label: 'File $name${a.size == null ? '' : ', ${fileSize(a.size!)}'}',
      child: InkWell(
        borderRadius: BorderRadius.circular(RelayRadius.lg),
        onTap: sending || message.sendState == SendState.failed ? null : open,
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.all(RelaySpace.s1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: mine ? p.onInk.withValues(alpha: 0.12) : p.fillMuted,
                    borderRadius: BorderRadius.circular(RelayRadius.md),
                  ),
                  child: sending
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: fg,
                          ),
                        )
                      : Text(
                          ext.length > 4 ? ext.substring(0, 4) : ext,
                          style: TextStyle(
                            fontFamily: RelayFonts.mono,
                            fontSize: 11,
                            color: fg,
                          ),
                        ),
                ),
                const SizedBox(width: RelaySpace.s3),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: RelayFonts.sans,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: fg,
                        ),
                      ),
                      Text(
                        a.size == null ? ext : '$ext · ${fileSize(a.size!)}',
                        style: TextStyle(
                          fontFamily: RelayFonts.mono,
                          fontSize: 12,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Voice note: play/pause, waveform bars (progress-filled), duration.
class VoiceAttachmentView extends ConsumerStatefulWidget {
  const VoiceAttachmentView({
    super.key,
    required this.message,
    required this.mine,
  });

  final Message message;
  final bool mine;

  @override
  ConsumerState<VoiceAttachmentView> createState() =>
      _VoiceAttachmentViewState();
}

class _VoiceAttachmentViewState extends ConsumerState<VoiceAttachmentView> {
  AudioPlayer? _player;
  final _subs = <StreamSubscription<Object?>>[];
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _loading = false;

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final a = widget.message.attachment!;
    if (_state == PlayerState.playing) {
      await _player?.pause();
      return;
    }
    if (_player != null && _state == PlayerState.paused) {
      await _player!.resume();
      return;
    }
    setState(() => _loading = true);
    try {
      final url = await ref
          .read(messageRepositoryProvider)
          .attachmentUrl(a.path);
      final player = _player ??= _createPlayer();
      await player.play(UrlSource(url));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn’t play this voice note.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  AudioPlayer _createPlayer() {
    final player = AudioPlayer();
    _subs
      ..add(
        player.onPlayerStateChanged.listen((s) {
          if (!mounted) return;
          setState(() {
            _state = s;
            if (s == PlayerState.completed) _position = Duration.zero;
          });
        }),
      )
      ..add(
        player.onPositionChanged.listen((d) {
          if (mounted) setState(() => _position = d);
        }),
      )
      ..add(
        player.onDurationChanged.listen((d) {
          if (mounted) setState(() => _duration = d);
        }),
      );
    return player;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final a = widget.message.attachment!;
    final mine = widget.mine;
    final fg = mine ? p.onInk : p.ink;
    final total = _duration ?? Duration(milliseconds: a.durationMs ?? 0);
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final playing = _state == PlayerState.playing;
    final canPlay = widget.message.sendState == SendState.sent;
    final shown = playing || _state == PlayerState.paused ? _position : total;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            tooltip: playing ? 'Pause voice note' : 'Play voice note',
            style: IconButton.styleFrom(
              backgroundColor: mine ? p.onInk : p.ink,
              foregroundColor: mine ? p.ink : p.onInk,
            ),
            onPressed: canPlay && !_loading ? _toggle : null,
            icon: _loading || widget.message.sendState == SendState.sending
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: mine ? p.ink : p.onInk,
                    ),
                  )
                : Icon(playing ? Icons.pause : Icons.play_arrow),
          ),
        ),
        const SizedBox(width: RelaySpace.s2),
        ExcludeSemantics(
          child: Waveform(
            samples: a.waveform,
            progress: progress,
            color: fg,
            dimColor: fg.withValues(alpha: 0.35),
          ),
        ),
        const SizedBox(width: RelaySpace.s2),
        Text(
          duration(shown),
          style: TextStyle(
            fontFamily: RelayFonts.mono,
            fontSize: 12,
            color: mine ? p.onInk.withValues(alpha: 0.8) : p.textSubtle,
          ),
        ),
      ],
    );
  }
}

/// Vertical bars from 0–1 samples; bars left of [progress] use [color].
class Waveform extends StatelessWidget {
  const Waveform({
    super.key,
    required this.samples,
    required this.color,
    required this.dimColor,
    this.progress = 1,
    this.bars = 32,
    this.height = 28,
  });

  final List<double> samples;
  final double progress;
  final Color color;
  final Color dimColor;
  final int bars;
  final double height;

  @override
  Widget build(BuildContext context) {
    final values = resample(samples, bars);
    return SizedBox(
      height: height,
      width: bars * 4.0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < bars; i++)
            Container(
              width: 2,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              height: 3 + values[i] * (height - 3),
              decoration: BoxDecoration(
                color: (i + 0.5) / bars <= progress ? color : dimColor,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }

  /// Averages [samples] into [count] buckets (flat line when empty).
  static List<double> resample(List<double> samples, int count) {
    if (samples.isEmpty) return List.filled(count, 0.15);
    return [
      for (var i = 0; i < count; i++)
        () {
          final start = (i * samples.length / count).floor();
          final end = ((i + 1) * samples.length / count).ceil().clamp(
            start + 1,
            samples.length,
          );
          var sum = 0.0;
          for (var j = start; j < end; j++) {
            sum += samples[j];
          }
          return (sum / (end - start)).clamp(0.0, 1.0);
        }(),
    ];
  }
}
