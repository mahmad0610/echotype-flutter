import 'dart:io'; // For File
import 'dart:async'; // For TimeoutException
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:http/io_client.dart' as http show IOClient;
import 'package:retry/retry.dart'; // Ensure this import is correct
// For runtime permissions

class NetworkConfig {
  static const String baseUrl = 'https://echotype-backend-production.up.railway.app'; // Railway domain
  static const String endpoint = '/transcribe';

  // Disabled permission check - relying on manifest
  static Future<void> requestPermissions() async {
    _log('Permissions assumed from manifest');
  }

  static Future<http.Response> postAudio(String audioPath) async {
    final file = File(audioPath);
    if (!file.existsSync()) {
      throw Exception('Audio file not found at $audioPath');
    }

    // Removed permission request
    await requestPermissions();

    return await retry(
      () async {
        final uri = Uri.parse('$baseUrl$endpoint');
        final request = http.MultipartRequest('POST', uri)
          ..files.add(await http.MultipartFile.fromPath('audio', audioPath));

        HttpClient httpClient = HttpClient();
        httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) => true; // Bypass SSL for testing
        httpClient.connectionTimeout = const Duration(seconds: 30);
        final ioClient = http.IOClient(httpClient);

        try {
          _log('Sending request to $uri');
          final streamedResponse = await ioClient.send(request).timeout(const Duration(seconds: 30));
          final response = await http.Response.fromStream(streamedResponse);
          _log('Received response: Status ${response.statusCode}, Body: ${response.body}');
          if (response.statusCode == 200) {
            return response;
          } else {
            throw Exception('Server error: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          _log('Error during request: $e');
          rethrow;
        } finally {
          ioClient.close();
        }
      },
      retryIf: (e) => e is SocketException || e is http.ClientException || e is TimeoutException,
      maxAttempts: 3,
      delayFactor: Duration(seconds: 5),
      maxDelay: Duration(seconds: 20),
      onRetry: (e) => _log('Retrying due to error: $e'),
    );
  }

  static void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    debugPrint('[NetworkConfig] [$timestamp] $message');
  }
}
