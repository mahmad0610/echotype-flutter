import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:markdown_widget/markdown_widget.dart'; // Added for Markdown rendering
import 'network_config.dart' as network;
import 'notes_screen.dart';

class ListeningScreen extends StatefulWidget {
  const ListeningScreen({super.key});

  @override
  ListeningScreenState createState() => ListeningScreenState();
}

class ListeningScreenState extends State<ListeningScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    try {
      var micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        _log('Microphone permission denied: $micStatus');
        _showError('Microphone permission is required to record audio');
        return;
      }
      _log('Recorder initialized with microphone permission');
    } catch (e) {
      _log('Recorder initialization error: $e');
      _showError('Failed to initialize recorder');
    }
  }

  Future<void> _startRecording() async {
    try {
      var micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        _log('Microphone permission not granted, requesting...');
        micStatus = await Permission.microphone.request();
        if (!micStatus.isGranted) {
          _log('Microphone permission denied: $micStatus');
          _showError('Microphone permission is required');
          return;
        }
      }

      Directory tempDir = await getTemporaryDirectory();
      _filePath = '${tempDir.path}/audio.wav';
      _log('Recording to: $_filePath');

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _filePath!,
      );
      setState(() => _isRecording = true);
      _log('Recording started');
    } catch (e) {
      _log('Start error: $e');
      _showError('Failed to start: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      _log('Stopping recording...');
      await _recorder.stop();
      _log('Recorder stopped');

      if (_filePath != null) {
        File file = File(_filePath!);
        if (await file.exists()) {
          int fileSize = await file.length();
          _log('File checked. Path: $_filePath, Size: $fileSize bytes');
          if (fileSize <= 44) {
            _log('Warning: File size too small, no audio captured');
            _showError('No audio captured');
            setState(() {
              _isRecording = false;
              _isProcessing = false;
            });
          } else {
            _log('Audio recorded successfully, size valid');
            List<int> bytes = await file.readAsBytes();
            if (bytes.length < 44 || !bytes.sublist(0, 4).every((b) => b == 0x52 || b == 0x49 || b == 0x46 || b == 0x46)) {
              _log('Warning: Invalid WAV file');
              _showError('Invalid audio file recorded');
              setState(() {
                _isRecording = false;
                _isProcessing = false;
              });
            } else {
              setState(() {
                _isRecording = false;
                _isProcessing = true;
              });
              _log('Sending to backend...');
              await _sendAudioToBackend();
              _log('Backend call completed');
            }
          }
        } else {
          _log('Error: Audio file does not exist');
          _showError('Recording failed: File not found');
          setState(() {
            _isRecording = false;
            _isProcessing = false;
          });
        }
      } else {
        _log('Error: No file path available');
        _showError('Recording failed: No file path');
        setState(() {
          _isRecording = false;
          _isProcessing = false;
        });
      }
    } catch (e) {
      _log('Stop error: $e');
      _showError('Failed to stop: $e');
      setState(() {
        _isRecording = false;
        _isProcessing = false;
      });
    }
  }

  Future<void> _sendAudioToBackend() async {
    if (_filePath == null || !File(_filePath!).existsSync()) {
      _showError('No valid audio file found.');
      setState(() => _isProcessing = false);
      return;
    }

    try {
      _log('Sending audio file to backend...');
      final response = await network.NetworkConfig.postAudio(_filePath!);
      final responseData = jsonDecode(response.body);

      _log('Response received: $responseData');

      if (response.statusCode == 200 && mounted) {
        final transcription = responseData['transcription']?.toString() ?? 'No transcription available';
        final formattedNotes = responseData['formattedNotes']?.toString() ?? 'No notes available';

        _log('Navigating to NotesScreen with transcription: $transcription');
        _log('Navigating to NotesScreen with formattedNotes: $formattedNotes');

        if (transcription == "No transcription available" || formattedNotes == "No notes available") {
          _showError('Transcription failed. Please try a longer recording.');
        } else {
          setState(() => _isProcessing = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NotesScreen(
                transcription: transcription,
                formattedNotes: formattedNotes,
              ),
            ),
          );
        }
      } else if (mounted) {
        _showError('Error ${response.statusCode}: $responseData');
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to connect to server: $e');
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      _log('Error: $message');
    }
  }

  void _log(String message) {
    debugPrint('[ListeningScreen] $message');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isProcessing)
              const CircularProgressIndicator()
            else
              Text(_isRecording ? 'Recording...' : 'Ready'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              child: Text(_isRecording ? 'Stop' : 'Start'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }
}
