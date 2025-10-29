import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/usuario.dart';
import '../config/api_config.dart';

enum ChatSection {
  cliente,
  ciaBot,
  soporte,
  historial,
}

class ChatScreen extends StatefulWidget {
  final ChatSection initialSection;
  final Usuario currentUser;
  final int? idConversacion; // Nuevo: ID de conversación opcional

  const ChatScreen(
      {super.key,
      required this.currentUser,
      this.idConversacion, // Nuevo: Parámetro opcional
      this.initialSection = ChatSection.cliente});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  int? _idConversacion; // Ahora es parte del estado
  // Lista de mensajes que se muestran en la UI
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _idConversacion =
        widget.idConversacion; // Inicializar con el ID del widget si existe
    _loadMessages();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Helper para obtener el título de la AppBar según la sección
  String _getAppBarTitle() {
    switch (widget.initialSection) {
      case ChatSection.cliente:
        return 'Chat con Cliente';
      case ChatSection.soporte:
        return 'Chat con Soporte';
      case ChatSection.ciaBot:
        return 'Asistente Virtual (CIA Bot)';
      case ChatSection.historial:
        return 'Historial de Chat'; // Si esta sección se usara para chat activo
    }
  }

  // Helper para obtener el mensaje inicial del bot según la sección
  String _getInitialBotMessage() {
    switch (widget.initialSection) {
      case ChatSection.cliente:
        return '¡Hola! Estoy aquí para ayudarte con tu pedido. ¿En qué puedo asistirte?';
      case ChatSection.soporte:
        return '¡Bienvenido al chat de soporte! Por favor, describe tu problema.';
      case ChatSection.ciaBot:
        return '¡Hola! Soy tu Asistente Virtual. ¿Tienes alguna pregunta sobre nuestros productos o servicios?';
      case ChatSection.historial:
        return 'Aquí puedes ver el historial de tu conversación.';
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      if (_idConversacion != null) {
        // Si ya tenemos un ID de conversación, cargamos el historial
        _messages = await _getHistorial(_idConversacion);
      } else {
        // Si no, mostramos el mensaje de bienvenida inicial del bot
        _messages = [
          ChatMessage(
              text: _getInitialBotMessage(),
              isBot: true,
              time: DateTime.now(),
              senderName: _getAppBarTitle()),
        ];
      }
      setState(() => _isLoading = false);
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _error = "Error al cargar mensajes iniciales.";
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Añadir el mensaje del usuario inmediatamente a la UI
    setState(() {
      _messages.add(ChatMessage(
          text: text,
          isBot: false,
          time: DateTime.now(),
          senderName: widget.currentUser.nombre));
      _isSending = true;
    });
    _controller.clear();
    _scrollToBottom(); // Desplazarse para mostrar el nuevo mensaje del usuario

    try {
      final idRemitente =
          widget.currentUser.idUsuario; // Ya se obtiene del widget
      final response = await _sendToBackend(text, idRemitente, _idConversacion);
      if (response["id_conversacion"] != null) {
        final convId = response["id_conversacion"];
        if (convId is int) {
          _idConversacion = convId;
        } else if (convId is String) {
          _idConversacion = int.tryParse(convId);
        } else if (convId is num) {
          _idConversacion = convId.toInt();
        }
      }
      // Obtener historial actualizado
      final mensajes = await _getHistorial(_idConversacion);
      // Detectar si la respuesta del bot es un fallback (por coincidencia de texto)
      final tieneFallback = mensajes.isNotEmpty &&
          mensajes.last.isBot &&
          (mensajes.last.text.contains("no está conectado") ||
              mensajes.last.text.contains("problema para procesar") ||
              mensajes.last.text.contains("No pude conectarme") ||
              mensajes.last.text.contains("No entendí la respuesta"));
      setState(() {
        _messages =
            mensajes; // Reemplazar con el historial completo (incluye el mensaje del usuario y la respuesta del bot)
        _isSending = false;
        _error = tieneFallback
            ? "El bot no está disponible o hubo un problema con la IA. Intenta más tarde o contacta soporte."
            : null;
      });
      _scrollToBottom();
    } catch (e) {
      // Capturar cualquier excepción durante el envío o la carga del historial
      setState(() {
        // Mostrar un mensaje de error más detallado
        _error =
            "No se pudo enviar el mensaje. Verifica tu conexión o intenta más tarde.";
        _isSending = false;
      });
    }
  }

  Future<Map<String, dynamic>> _sendToBackend(
      String userMessage, int idRemitente, int? idConversacion) async {
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
      // Lanzar una excepción con el código de estado y el cuerpo de la respuesta
      // para más detalles en la consola de depuración.
      throw Exception(
          'Error en la respuesta del backend: ${response.statusCode}');
    }
  }

  Future<List<ChatMessage>> _getHistorial(int? idConversacion) async {
    if (idConversacion == null) {
      return []; // Si no hay ID de conversación, no hay historial que buscar
    }
    final url = Uri.parse(
        '${AppConfig.baseUrl}/chat/conversaciones/$idConversacion/mensajes'); // Endpoint corregido
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response
          .bodyBytes)); // Usar utf8.decode para evitar problemas con tildes
      if (data["success"] == true && data["data"] is List) {
        final mensajes = <ChatMessage>[];
        for (final msg in data["data"]) {
          final texto = msg["mensaje"]?.toString() ?? "";
          final isBot =
              msg["id_remitente"]?.toString() == "0" || (msg["esBot"] == true);
          final fecha = msg["fecha"] ??
              msg["created_at"] ??
              DateTime.now().toIso8601String();
          // Asignar el nombre del remitente según si es bot o usuario actual
          final senderName =
              isBot ? _getAppBarTitle() : widget.currentUser.nombre;
          mensajes.add(ChatMessage(
            text: texto,
            isBot: isBot,
            time: DateTime.tryParse(fecha) ?? DateTime.now(),
            senderName: senderName,
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
        // AppBar con título dinámico
        title: Text(_getAppBarTitle()),
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
                        return _buildMessageBubble(
                            msg); // Usar un helper para construir la burbuja
                      },
                    ),
            ),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(8.0),
                color: Colors.red.shade100,
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: TextStyle(color: Colors.red.shade800)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() => _error = null),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              color: Colors.blueGrey[100],
              child: Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (context, value, child) {
                        return TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'Escribe tu mensaje...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25.0),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            suffixIcon: value.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _controller.clear();
                                    },
                                  )
                                : null,
                            isDense: true,
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isSending
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send, color: Colors.blueGrey),
                          onPressed: _sendMessage,
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

  // Widget helper para construir las burbujas de mensaje
  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = !msg.isBot;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = isUser ? Colors.blue[200] : Colors.blueGrey[100];
    final textColor = Colors.black;
    final borderRadius = BorderRadius.circular(16);

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: color,
          borderRadius: borderRadius.copyWith(
            topLeft:
                isUser ? const Radius.circular(16) : const Radius.circular(0),
            topRight:
                isUser ? const Radius.circular(0) : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (msg.senderName != null && msg.senderName!.isNotEmpty)
              Text(
                msg.senderName!,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color:
                      isUser ? Colors.blue.shade800 : Colors.blueGrey.shade800,
                ),
              ),
            if (msg.senderName != null && msg.senderName!.isNotEmpty)
              const SizedBox(height: 4),
            Text(msg.text, style: TextStyle(color: textColor, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              _formatTime(msg.time),
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isBot;
  final DateTime time;
  final String? senderName; // Nuevo campo para el nombre del remitente

  ChatMessage(
      {required this.text,
      required this.isBot,
      required this.time,
      this.senderName});
}
