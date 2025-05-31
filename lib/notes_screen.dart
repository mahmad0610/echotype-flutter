import 'package:flutter/material.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? formattedNotes = ModalRoute.of(context)?.settings.arguments as String?;
    return Scaffold(
      appBar: AppBar(title: const Text('Formatted Notes')),
      body: SingleChildScrollView(
        child: formattedNotes != null
            ? Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(formattedNotes, style: const TextStyle(color: Colors.white)),
              )
            : const Center(child: Text('No notes available', style: TextStyle(color: Colors.white))),
      ),
      backgroundColor: const Color(0xFF010101),
    );
  }
}