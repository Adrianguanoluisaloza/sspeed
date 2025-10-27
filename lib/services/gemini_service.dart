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
      return _fallbackReply(prompt);
    }

    final uri = Uri.parse('$_endpoint?key=$_apiKey');
    final contents = <Map<String, dynamic>>[
      {
        'role': 'user',
        'parts': [
          {
            'text':
                'Eres un asistente virtual de soporte para una aplicación de delivery llamada Unite7speed. '
                    'Responde con mensajes cortos, empáticos y accionables. '
                    'Si el usuario pregunta por un pedido, limita la respuesta a posibles soluciones '
                    'y nunca inventes información.'
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
        return _fallbackReply(prompt);
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

      return _fallbackReply(prompt);
    } catch (e, stack) {
      debugPrint('GeminiService exception: $e\n$stack');
      return _fallbackReply(prompt);
    }
  }

  String _fallbackReply(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains('hola')) {
      return 'Hola! Estoy listo para ayudarte con tu pedido.';
    }
    if (lower.contains('pedido') || lower.contains('orden')) {
      return 'Estoy verificando la información de tu pedido. Enseguida te comento los pasos a seguir.';
    }
    if (lower.contains('gracias')) {
      return 'Gracias a ti. Si necesitas algo más, aquí estoy.';
    }
    return 'Estoy aquí para ayudarte. ¿Quieres conocer el estado de un pedido o necesitas soporte con la app?';
  }
}
