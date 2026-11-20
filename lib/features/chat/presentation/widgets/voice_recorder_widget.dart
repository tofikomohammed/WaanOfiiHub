import 'package:flutter/material.dart';
import 'package:record/record.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final Function(String path) onRecordingComplete;

  const VoiceRecorderWidget({super.key, required this.onRecordingComplete});

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        const config = RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 32000,
          sampleRate: 44100,
        );
        await _audioRecorder.start(config, path: '');
        setState(() => _isRecording = true);
      }
    } catch (_) {}
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null && path.isNotEmpty) {
        widget.onRecordingComplete(path);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(_isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded),
      color: _isRecording ? Colors.red : null,
      tooltip: _isRecording ? 'Stop Recording' : 'Hold to Record Voice Note',
      onPressed: () {
        if (_isRecording) {
          _stopRecording();
        } else {
          _startRecording();
        }
      },
    );
  }
}
