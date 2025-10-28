import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/secret_config.dart';
import '../models/chat_message.dart';

class GeminiService {
  GeminiService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = (apiKey ?? SecretConfig.geminiApiKey).trim();

  final http.Client _client;
  final String _apiKey;

  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash-latest:generateContent';

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<String> generateReply({
    required String prompt,
    required int currentUserId,
    List<ChatMessage> history = const [],
  }) async {
    if (_apiKey.isEmpty) {
      return 'No se pudo conectar a la IA.';
    }

    final uri = Uri.parse('$_endpoint?key=$_apiKey');
    // Prompt inicial sin restricciones, solo identidad y tono amigable
    final contents = <Map<String, dynamic>>[
      {
        'role': 'user',
        'parts': [
          {
            'text':
                'Eres CIA Bot, un asistente virtual amigable y curioso. Puedes responder cualquier pregunta sobre delivery, tecnología, curiosidades, consejos, o simplemente conversar. Sé empático y útil.'
          },
        ],
      },
    ];

    final limitedHistory = history.length > 10
        ? history.sublist(history.length - 10)
        : history;

    for (final message in limitedHistory) {
      final role = message.idRemitente == currentUserId ? 'user' : 'model';
      final text = message.mensaje.trim();
      if (text.isEmpty) continue;
      contents.add({
        'role': role,
        'parts': [
          {'text': text},
        ],
      });
    }

    contents.add({
      'role': 'user',
      'parts': [
        {'text': prompt},
      ],
    });

    final payload = jsonEncode({'contents': contents});

    try {
      final response = await _client.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: payload,
      );

      if (response.statusCode != 200) {
        debugPrint(
          'GeminiService error ${response.statusCode}: ${response.body}',
        );
        return 'No se pudo obtener respuesta de la IA.';
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'];
      if (candidates is List && candidates.isNotEmpty) {
        final first = candidates.first as Map<String, dynamic>;
        final content = first['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>? ?? const [];
        final buffer = StringBuffer();
        for (final part in parts) {
          if (part is Map && part['text'] is String) {
            buffer.write(part['text'] as String);
          }
        }
        final text = buffer.toString().trim();
        if (text.isNotEmpty) return text;
      }

  return 'No se pudo obtener respuesta de la IA.';
    } catch (e, stack) {
      debugPrint('GeminiService exception: $e\n$stack');
  return 'No se pudo obtener respuesta de la IA.';
    }
  }

  // Eliminado método de respuestas predeterminadas
}
