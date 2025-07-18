import 'package:flutter/material.dart';
import 'welcome_screen.dart';
import 'main_menu_screen.dart';
import 'listening_screen.dart';
import 'notes_screen.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestMicrophonePermission();
  runApp(const EchoTypeApp());
}

Future<void> _requestMicrophonePermission() async {
  var status = await Permission.microphone.request();
  if (status.isDenied || status.isPermanentlyDenied) {
    _log('Microphone permission denied');
  }
}

void _log(String message) {
  debugPrint(message);
}

class EchoTypeApp extends StatelessWidget {
  const EchoTypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EchoType',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/main_menu': (context) => const MainMenuScreen(),
        '/listening': (context) => const ListeningScreen(),
        '/notes': (context) => const NotesScreen(
          transcription: 'No transcription available',
          formattedNotes: 'No notes available',
        ), // Added default arguments to fix errors
      },
    );
  }
}
