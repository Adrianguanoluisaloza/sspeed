import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

enum ChatSection {
  cliente,
  ciaBot,
  soporte,
  historial,
}

class ChatScreen extends StatefulWidget {
  final ChatSection initialSection;
  const ChatScreen({super.key, this.initialSection = ChatSection.cliente});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      // Simulación de carga desde API
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        _messages = [
          ChatMessage(text: "¡Hola! ¿En qué puedo ayudarte?", isBot: true, time: DateTime.now()),
        ];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Error al cargar mensajes";
        _isLoading = false;
      });
    }
  }

  int? _idConversacion;

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    _controller.clear();
    try {
      // Obtener idRemitente real del usuario (ejemplo: desde Provider o SessionController)
      final idRemitente = ModalRoute.of(context)?.settings.arguments is int
        ? ModalRoute.of(context)!.settings.arguments as int
        : 1;
      final response = await _sendToBackend(text, idRemitente, _idConversacion);
      if (response["id_conversacion"] != null) {
        _idConversacion = response["id_conversacion"] is int
          ? response["id_conversacion"]
          : int.tryParse(response["id_conversacion"].toString());
      }
      // Obtener historial actualizado
      final mensajes = await _getHistorial(_idConversacion);
      // Detectar si la respuesta del bot es un fallback
      final tieneFallback = mensajes.isNotEmpty && mensajes.last.isBot && (
        mensajes.last.text.contains("no está conectado") ||
        mensajes.last.text.contains("problema para procesar") ||
        mensajes.last.text.contains("No pude conectarme") ||
        mensajes.last.text.contains("No entendí la respuesta")
      );
      setState(() {
        _messages = mensajes;
        _isSending = false;
        _error = tieneFallback
          ? "El bot no está disponible o hubo un problema con la IA. Intenta más tarde o contacta soporte."
          : null;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _error = "No se pudo enviar el mensaje. Verifica tu conexión o intenta más tarde.";
        _isSending = false;
      });
    }
  }

  Future<Map<String, dynamic>> _sendToBackend(String userMessage, int idRemitente, int? idConversacion) async {
  // Usar la URL base real del backend
  final url = Uri.parse('${AppConfig.baseUrl}/chat/bot/mensajes');
    final payload = {
      "idRemitente": idRemitente,
      "mensaje": userMessage,
      if (idConversacion != null) "idConversacion": idConversacion,
    };
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data["success"] == true && data["data"] != null) {
        return data["data"] as Map<String, dynamic>;
      } else {
        throw Exception("Respuesta inesperada del backend: ${response.body}");
      }
    } else {
      throw Exception('Error en la respuesta del backend: ${response.statusCode}');
    }
  }

  Future<List<ChatMessage>> _getHistorial(int? idConversacion) async {
    if (idConversacion == null) return [];
  final url = Uri.parse('${AppConfig.baseUrl}/chat/conversaciones/$idConversacion/mensajes');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data["success"] == true && data["data"] is List) {
        final mensajes = <ChatMessage>[];
        for (final msg in data["data"]) {
          final texto = msg["mensaje"]?.toString() ?? "";
          final isBot = msg["id_remitente"]?.toString() == "0" || (msg["esBot"] == true);
          final fecha = msg["fecha"] ?? msg["created_at"] ?? DateTime.now().toIso8601String();
          mensajes.add(ChatMessage(
            text: texto,
            isBot: isBot,
            time: DateTime.tryParse(fecha) ?? DateTime.now(),
          ));
        }
        return mensajes;
      }
    }
    return [];
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Bot'),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: Container(
        color: Colors.blueGrey[50],
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        return Align(
                          alignment: msg.isBot ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: msg.isBot ? Colors.blueGrey[100] : Colors.blue[200],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: msg.isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                              children: [
                                Text(msg.text, style: TextStyle(color: Colors.black, fontSize: 16)),
                                SizedBox(height: 4),
                                Text(
                                  _formatTime(msg.time),
                                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_error!, style: TextStyle(color: Colors.red)),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              color: Colors.blueGrey[100],
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Escribe tu mensaje...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isSending
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.send, color: Colors.blueGrey),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }
}

class ChatMessage {
  final String text;
  final bool isBot;
  final DateTime time;
  ChatMessage({required this.text, required this.isBot, required this.time});
}