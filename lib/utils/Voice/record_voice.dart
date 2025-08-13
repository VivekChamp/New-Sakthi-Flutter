import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class RecordVoice extends StatefulWidget {
  final Function(String? filePath)? onRecordingComplete;
  final VoidCallback? onRecordingStarted;
  final VoidCallback? onRecordingStopped;

  const RecordVoice({
    Key? key,
    this.onRecordingComplete,
    this.onRecordingStarted,
    this.onRecordingStopped,
  }) : super(key: key);

  @override
  _RecordVoiceState createState() => _RecordVoiceState();
}

class _RecordVoiceState extends State<RecordVoice> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  String? _audioPath;
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initRecorder() async {
    try {
      await _recorder.openRecorder();
    } catch (e) {
      print('Error initializing recorder: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await Permission.microphone.request().isGranted) {
        final tempDir = await getTemporaryDirectory();
        final filePath =
            '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
        await _recorder.startRecorder(
          toFile: filePath,
          codec: Codec.aacADTS,
        );
        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
        });
        _startTimer();
        widget.onRecordingStarted?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission denied'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting recording: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
      _timer?.cancel();
      widget.onRecordingComplete?.call(path);
      widget.onRecordingStopped?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error stopping recording: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration++;
      });
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(
            _isRecording ? Icons.stop_circle : Icons.mic,
            color: Theme.of(context).colorScheme.primary,
            size: 32,
          ),
          onPressed: _isRecording ? _stopRecording : _startRecording,
        ),
        const SizedBox(width: 8),
        Text(
          _isRecording
              ? _formatDuration(_recordingDuration)
              : _audioPath != null
                  ? 'Recording ready'
                  : 'Tap to record',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xff000000),
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}
