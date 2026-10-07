import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/app_failure.dart';
import '../../../../core/format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../domain/message.dart';
import '../media_picker.dart';
import 'attachment_views.dart';
import 'message_bubble.dart';

/// Desktop and web send on Enter (Shift + Enter = new line).
bool get _enterSends =>
    kIsWeb ||
    switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };

/// Message input: attach menu, text, and a send / record button.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.onSendText,
    required this.onSendAttachment,
    required this.onTyping,
    this.replyTo,
    this.onCancelReply,
    this.editing,
    this.onCancelEdit,
  });

  final Future<void> Function(String text) onSendText;
  final Future<void> Function(OutgoingAttachment attachment) onSendAttachment;
  final VoidCallback onTyping;
  final ReplyPreview? replyTo;
  final VoidCallback? onCancelReply;

  /// When set, the field holds this message's text and sending saves an edit.
  final Message? editing;
  final VoidCallback? onCancelEdit;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _text = TextEditingController();
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKey);
  _Recording? _recording;

  bool get _hasText => _text.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(Composer old) {
    super.didUpdateWidget(old);
    final editing = widget.editing;
    if (editing != null && editing.id != old.editing?.id) {
      _text.text = editing.body ?? '';
      _text.selection = TextSelection.collapsed(offset: _text.text.length);
      _focus.requestFocus();
    } else if (editing == null && old.editing != null) {
      _text.clear();
    }
    if (widget.replyTo != null && widget.replyTo?.id != old.replyTo?.id) {
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _recording?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_enterSends || event is! KeyDownEvent) return KeyEventResult.ignored;
    final enter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!enter || HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    _submit();
    return KeyEventResult.handled;
  }

  Future<void> _submit() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    _text.clear();
    await widget.onSendText(text);
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mapAppError(e).message)));
  }

  Future<void> _attach() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Photo'),
              onTap: () => Navigator.pop(context, 'photo'),
            ),
            if (cameraAvailable)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, 'camera'),
              ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('File'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
            const SizedBox(height: RelaySpace.s2),
          ],
        ),
      ),
    );
    if (choice == null) return;
    try {
      final picked = switch (choice) {
        'photo' => await pickPhoto(),
        'camera' => await pickPhoto(camera: true),
        _ => await pickAnyFile(),
      };
      if (picked != null) await widget.onSendAttachment(picked);
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _startRecording() async {
    final rec = _Recording(
      onTick: () {
        if (mounted) setState(() {});
      },
    );
    try {
      final ok = await rec.start();
      if (!ok) {
        await rec.cancel();
        _showError(
          const AppFailure(
            'Microphone access is off. Turn it on in Settings to record.',
          ),
        );
        return;
      }
      if (mounted) setState(() => _recording = rec);
    } catch (e) {
      await rec.cancel();
      _showError(const AppFailure('Couldn’t start recording.'));
    }
  }

  Future<void> _finishRecording() async {
    final rec = _recording;
    if (rec == null) return;
    setState(() => _recording = null);
    try {
      final note = await rec.stop();
      if (note != null) await widget.onSendAttachment(note);
    } catch (e) {
      _showError(const AppFailure('Couldn’t save the voice note.'));
    }
  }

  Future<void> _cancelRecording() async {
    final rec = _recording;
    setState(() => _recording = null);
    await rec?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = context.metrics;
    final editing = widget.editing;
    final reply = widget.replyTo;
    final rec = _recording;
    final buttonSize = m.circularAvatars ? 52.0 : 44.0;

    final Widget bar;
    if (editing != null) {
      bar = _ContextBar(
        icon: Icons.edit_outlined,
        title: 'Editing message',
        subtitle: editing.body ?? '',
        closeLabel: 'Cancel edit',
        onClose: widget.onCancelEdit,
      );
    } else if (reply != null) {
      bar = _ContextBar(
        icon: Icons.reply,
        title: 'Replying to ${reply.senderName ?? 'message'}',
        subtitle: ReplyQuote.snippet(reply),
        closeLabel: 'Cancel reply',
        onClose: widget.onCancelReply,
      );
    } else {
      bar = const SizedBox.shrink();
    }

    final Widget input;
    if (rec != null) {
      input = Expanded(
        child: Container(
          height: buttonSize,
          padding: const EdgeInsets.symmetric(horizontal: RelaySpace.s2),
          decoration: BoxDecoration(
            color: p.fillMuted,
            borderRadius: BorderRadius.circular(RelayRadius.pill),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Discard voice note',
                icon: Icon(Icons.delete_outline, color: p.dangerText),
                onPressed: _cancelRecording,
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: p.danger,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: RelaySpace.s2),
              Text(
                duration(rec.elapsed),
                semanticsLabel: 'Recording, ${rec.elapsed.inSeconds} seconds',
                style: TextStyle(
                  fontFamily: RelayFonts.mono,
                  fontSize: 13,
                  color: p.ink,
                ),
              ),
              const SizedBox(width: RelaySpace.s3),
              Expanded(
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Waveform(
                      samples: rec.recent,
                      color: p.ink,
                      dimColor: p.ink,
                      bars: 28,
                      height: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      input = Expanded(
        child: Container(
          constraints: BoxConstraints(minHeight: buttonSize),
          decoration: BoxDecoration(
            color: p.fillMuted,
            borderRadius: BorderRadius.circular(RelayRadius.bubble + 2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Attach',
                icon: Icon(Icons.add_circle_outline, color: p.textSecondary),
                onPressed: editing == null ? _attach : null,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 6,
                    maxLength: 4000,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => widget.onTyping(),
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Message',
                      hintStyle: TextStyle(color: p.placeholder),
                      border: InputBorder.none,
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: RelaySpace.s3),
            ],
          ),
        ),
      );
    }

    final showSend = rec != null || _hasText || editing != null;
    final action = SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: IconButton(
        tooltip: rec != null
            ? 'Send voice note'
            : editing != null
            ? 'Save edit'
            : showSend
            ? 'Send'
            : 'Record voice note',
        style: IconButton.styleFrom(
          backgroundColor: p.ink,
          foregroundColor: p.onInk,
          disabledBackgroundColor: p.ink.withValues(alpha: 0.4),
        ),
        onPressed: rec != null
            ? _finishRecording
            : showSend
            ? (_hasText ? _submit : null)
            : _startRecording,
        icon: Icon(
          rec != null || (showSend && editing == null)
              ? Icons.arrow_upward
              : editing != null
              ? Icons.check
              : Icons.mic_none,
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: p.background,
          border: Border(top: BorderSide(color: p.hairline)),
        ),
        padding: const EdgeInsets.fromLTRB(
          RelaySpace.s3,
          RelaySpace.s2,
          RelaySpace.s3,
          RelaySpace.s2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            bar,
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                input,
                const SizedBox(width: RelaySpace.s2),
                action,
              ],
            ),
            if (_enterSends && rec == null)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, right: 4),
                  child: Text(
                    'Shift + Enter for a new line',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(fontSize: 12, color: p.textSubtle),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContextBar extends StatelessWidget {
  const _ContextBar({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.closeLabel,
    this.onClose,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String closeLabel;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: RelaySpace.s2),
      child: Row(
        children: [
          const SizedBox(width: RelaySpace.s2),
          Icon(icon, size: 18, color: p.accent),
          const SizedBox(width: RelaySpace.s2),
          Container(width: 2, height: 32, color: p.accent),
          const SizedBox(width: RelaySpace.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: closeLabel,
            icon: const Icon(Icons.close, size: 20),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// One voice-note recording: elapsed time + amplitude samples for the waveform.
class _Recording {
  _Recording({required this.onTick});

  static const maxLength = Duration(minutes: 5);

  final VoidCallback onTick;
  final _recorder = AudioRecorder();
  final _samples = <double>[];
  final _clock = Stopwatch();
  StreamSubscription<Amplitude>? _amp;
  Timer? _ticker;
  bool _done = false;

  Duration get elapsed => _clock.elapsed;

  /// The last few seconds, for the live waveform.
  List<double> get recent =>
      _samples.length <= 28 ? _samples : _samples.sublist(_samples.length - 28);

  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    final RecordConfig config;
    final String path;
    if (kIsWeb) {
      // WAV plays everywhere (Safari/iOS can't play the browser's WebM).
      config = const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      );
      path = '';
    } else {
      config = const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
      );
      final dir = await getTemporaryDirectory();
      path = '${dir.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    }
    await _recorder.start(config, path: path);
    _clock.start();
    _amp = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen((a) {
          // dBFS (-60..0) → 0..1
          _samples.add(((a.current + 60) / 60).clamp(0.0, 1.0));
        });
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      onTick();
      if (elapsed >= maxLength) _recorder.pause();
    });
    return true;
  }

  /// Null when the recording is too short to keep (under half a second).
  Future<OutgoingAttachment?> stop() async {
    if (_done) return null;
    _done = true;
    _clock.stop();
    _ticker?.cancel();
    await _amp?.cancel();
    final path = await _recorder.stop();
    await _recorder.dispose();
    if (path == null || elapsed < const Duration(milliseconds: 500)) {
      return null;
    }
    final bytes = await XFile(path).readAsBytes();
    return OutgoingAttachment(
      bytes: bytes,
      name: kIsWeb ? 'voice-note.wav' : 'voice-note.m4a',
      kind: AttachmentKind.audio,
      contentType: kIsWeb ? 'audio/wav' : 'audio/mp4',
      durationMs: elapsed.inMilliseconds.clamp(0, maxLength.inMilliseconds),
      waveform: Waveform.resample(_samples, 48),
    );
  }

  Future<void> cancel() async {
    if (_done) return;
    _done = true;
    _clock.stop();
    _ticker?.cancel();
    await _amp?.cancel();
    try {
      await _recorder.cancel();
    } catch (_) {}
    await _recorder.dispose();
  }
}
