import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class ListeningScreen extends StatefulWidget {
  const ListeningScreen({super.key});

  @override
  _ListeningScreenState createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    await Permission.microphone.request();
  }

  Future<void> _startRecording() async {
    Directory tempDir = await getTemporaryDirectory();
    _filePath = '${tempDir.path}/audio.wav';
    await _recorder.startRecorder(toFile: _filePath, codec: Codec.pcm16WAV);
    setState(() => _isRecording = true);
    debugPrint('Recording started. File path: $_filePath');
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    setState(() => _isRecording = false);
    debugPrint('Recording stopped.');
    _sendAudioToBackend();
  }

  Future<void> _sendAudioToBackend() async {
    if (_filePath == null || !File(_filePath!).existsSync()) {
      _showError('No valid audio file found.');
      return;
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://echotype-backend-production.up.railway.app/transcribe'), // Fixed URL with https://
    );
    request.files.add(await http.MultipartFile.fromPath('audio', _filePath!));

    try {
      debugPrint('Sending audio file to backend...');
      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      debugPrint('Status code: ${response.statusCode}');
      debugPrint('Response data: $responseData');

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(responseData);
        String formattedNotes = jsonResponse['formattedNotes'] ?? "No notes available";
        Navigator.pushNamed(context, '/notes', arguments: formattedNotes);
      } else {
        _showError('Error ${response.statusCode}: $responseData');
      }
    } catch (e) {
      _showError('Network error while sending audio: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    debugPrint('Error: $message');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listening')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_isRecording ? 'Recording...' : 'Press to Record'),
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
    _recorder.closeRecorder();
    super.dispose();
  }
}