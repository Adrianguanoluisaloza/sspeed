import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/database_service.dart';
import '../models/usuario.dart';
import '../routes/app_routes.dart';

enum ChatSection {
  cliente,
  ciaBot,
  soporte,
  historial,
}

class ChatScreen extends StatefulWidget {
  final ChatSection initialSection;
  final Usuario currentUser;
  final int? idConversacion;

  const ChatScreen({
    super.key,
    required this.currentUser,
    this.idConversacion,
    this.initialSection = ChatSection.cliente,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  bool _isSending = false;
  String? _error;
  int? _idConversacion;
  List<ChatEntry> _messages = const [];

  @override
  void initState() {
    super.initState();
    _idConversacion = widget.idConversacion;
    _loadMessages();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final initialMessages = await _loadInitialMessages();
      if (!mounted) return;
      setState(() {
        _messages = initialMessages;
        _isLoading = false;
        _error = null;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Error al cargar mensajes iniciales.';
      });
    }
  }

  Future<List<ChatEntry>> _loadInitialMessages() async {
    if (_idConversacion != null) {
      return await _getHistorial(_idConversacion);
    }

    if (widget.initialSection == ChatSection.ciaBot) {
      return [
        ChatEntry(
          text: _getInitialBotMessage(),
          isBot: true,
          time: DateTime.now(),
          senderName: _botDisplayName,
        ),
      ];
    }

    return const [];
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final requiresConversation =
        widget.initialSection != ChatSection.ciaBot;
    if (requiresConversation &&
        (_idConversacion == null || _idConversacion! <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No se encontro una conversacion activa. Regresa a la lista y selecciona un chat disponible.'),
        ),
      );
      return;
    }

    final outgoing = ChatEntry(
      text: text,
      isBot: false,
      time: DateTime.now(),
      senderName: widget.currentUser.nombre,
    );

    setState(() {
      _messages = [..._messages, outgoing];
      _isSending = true;
      _error = null;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      final response = await _sendToBackend(
        text,
        widget.currentUser.idUsuario,
        _idConversacion,
      );

      if (response['id_conversacion'] != null) {
        final raw = response['id_conversacion'];
        if (raw is int) {
          _idConversacion = raw;
        } else if (raw is num) {
          _idConversacion = raw.toInt();
        } else if (raw is String) {
          _idConversacion = int.tryParse(raw);
        }
      }

      if (response['success'] == false) {
        if (!mounted) return;
        setState(() {
          _isSending = false;
          _error = response['message']?.toString() ??
              'El bot no pudo procesar tu mensaje. Intenta nuevamente.';
        });
        return;
      }

      List<ChatEntry> updated = _messages;
      if (_idConversacion != null) {
        updated = await _getHistorial(_idConversacion);
      }

      final fallbackTriggered = _detectBotFallback(updated);

      if (!mounted) return;
      setState(() {
        _messages = updated;
        _isSending = false;
        _error = fallbackTriggered
            ? 'El bot no esta disponible o hubo un problema con la IA. Intenta mas tarde o contacta soporte.'
            : null;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _error =
            'No se pudo enviar el mensaje. Verifica tu conexion o intenta mas tarde.';
      });
    }
  }

  Future<Map<String, dynamic>> _sendToBackend(
    String userMessage,
    int idRemitente,
    int? idConversacion,
  ) async {
    final dbService = context.read<DatabaseService>();
    final response = await dbService.enviarMensaje(
      idConversacion: idConversacion ?? 0,
      idRemitente: idRemitente,
      mensaje: userMessage,
      esBot: widget.initialSection == ChatSection.ciaBot,
    );

    final data = (response['data'] is Map)
        ? Map<String, dynamic>.from(response['data'] as Map)
        : <String, dynamic>{};

    final resolvedId = _parseConversationId(
      data['id_conversacion'] ?? response['id_conversacion'] ?? idConversacion,
    );

    final botReply = data['bot_reply'] ?? response['bot_reply'];

    return {
      'id_conversacion': resolvedId ?? idConversacion,
      if (botReply != null) 'bot_reply': botReply,
      'success': response['success'] ?? true,
      'message': response['message'],
    };
  }

  int? _parseConversationId(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  Future<List<ChatEntry>> _getHistorial(int? idConversacion) async {
    if (idConversacion == null) {
      return _messages;
    }

    // CORRECCIÓN: Se utiliza el DatabaseService centralizado.
    final dbService = context.read<DatabaseService>();
    final messageModels =
        await dbService.getMensajesDeConversacion(idConversacion);

    final entries = <ChatEntry>[];
    for (final msg in messageModels) {
      final isBot = msg.esBot || _isBotUser(msg.idRemitente);
      final senderName =
          (msg.remitenteNombre != null && msg.remitenteNombre!.isNotEmpty)
              ? msg.remitenteNombre
              : _resolveSenderName(msg.idRemitente, isBot: isBot);

      entries.add(
        ChatEntry(
          text: msg.mensaje,
          isBot: isBot,
          time: msg.fechaEnvio ?? DateTime.now(),
          senderName: senderName,
        ),
      );
    }
    return entries;
  }

  bool _isBotUser(int senderId) => senderId <= 0;

  bool _detectBotFallback(List<ChatEntry> mensajes) {
    if (mensajes.isEmpty) return false;
    final last = mensajes.last;
    if (!last.isBot) return false;
    final text = last.text.toLowerCase();
    const patterns = [
      'no esta conectado',
      'problema para procesar',
      'no pude conectarme',
      'no entendi la respuesta',
      'mi cerebro',
      'intentalo de nuevo',
    ];
    return patterns.any(text.contains);
  }

  String _resolveSenderName(int senderId, {bool isBot = false}) {
    if (isBot) return _botDisplayName;
    if (senderId == widget.currentUser.idUsuario) {
      return widget.currentUser.nombre;
    }

    switch (widget.initialSection) {
      case ChatSection.cliente:
        return 'Cliente';
      case ChatSection.soporte:
        return 'Soporte';
      case ChatSection.ciaBot:
        return _botDisplayName;
      case ChatSection.historial:
        return 'Contacto';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  String _getAppBarTitle() {
    switch (widget.initialSection) {
      case ChatSection.cliente:
        return 'Chat con Cliente';
      case ChatSection.soporte:
        return 'Chat con Soporte';
      case ChatSection.ciaBot:
        return 'Asistente Virtual (CIA Bot)';
      case ChatSection.historial:
        return 'Historial de Chat';
    }
  }

  String _getInitialBotMessage() {
    switch (widget.initialSection) {
      case ChatSection.cliente:
        return 'Hola! Estoy aqui para ayudarte con tu pedido. En que puedo asistirte?';
      case ChatSection.soporte:
        return 'Bienvenido al chat de soporte. Por favor, describe tu problema.';
      case ChatSection.ciaBot:
        return 'Hola! Soy tu Asistente Virtual. Tienes alguna pregunta sobre nuestros productos o servicios?';
      case ChatSection.historial:
        return 'Aqui puedes ver el historial de tu conversacion.';
    }
  }

  String get _botDisplayName => 'CIA Bot';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: Colors.blueGrey[900],
        actions: [
          if (_detectBotFallback(_messages) &&
              widget.initialSection == ChatSection.ciaBot)
            IconButton(
              tooltip: 'Hablar con Soporte',
              icon: const Icon(Icons.support_agent),
              onPressed: () {
                Navigator.of(context).pushNamed(
                  AppRoutes.supportHome,
                  arguments: widget.currentUser,
                );
              },
            ),
        ],
      ),
      body: Container(
        color: Colors.blueGrey[50],
        child: Column(
          children: [
            if (_detectBotFallback(_messages))
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.amber.shade100,
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'El asistente no esta disponible ahora. Puedes intentar nuevamente o escribir a Soporte.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 12, bottom: 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
            ),
            if (_isSending && widget.initialSection == ChatSection.ciaBot)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
                child: Row(
                  children: const [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('CIA Bot está escribiendo...',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.shade100,
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() => _error = null),
                    ),
                  ],
                ),
              ),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      color: Colors.blueGrey[100],
      child: Row(
        children: [
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, child) {
                final canSend = value.text.trim().isNotEmpty && !_isSending;
                return TextField(
                  controller: _controller,
                  enabled: !_isSending,
                  decoration: InputDecoration(
                    hintText: 'Escribe tu mensaje...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    suffixIcon: value.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _controller.clear,
                          )
                        : null,
                    isDense: true,
                  ),
                  onSubmitted: (_) {
                    if (canSend) _sendMessage();
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          _isSending
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, child) {
                    final canSend = value.text.trim().isNotEmpty;
                    return IconButton(
                      icon: Icon(
                        Icons.send,
                        color: canSend
                            ? Colors.blueGrey
                            : Colors.blueGrey.shade300,
                      ),
                      onPressed: canSend ? _sendMessage : null,
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatEntry msg) {
    final isUser = !msg.isBot;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = isUser ? Colors.blue[200] : Colors.blueGrey[100];
    final borderRadius = BorderRadius.circular(16);

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
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
            Text(
              msg.text,
              style: const TextStyle(color: Colors.black, fontSize: 16),
            ),
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

  String _formatTime(DateTime time) {
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}

class ChatEntry {
  final String text;
  final bool isBot;
  final DateTime time;
  final String? senderName;

  const ChatEntry({
    required this.text,
    required this.isBot,
    required this.time,
    this.senderName,
  });
}
