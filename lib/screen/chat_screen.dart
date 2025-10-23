import 'package:flutter/material.dart';

/// Secciones disponibles en el centro de mensajería.
enum ChatSection { cliente, soporte, historial }

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _controller = TextEditingController();

  // Dividimos los mensajes por sección para permitir navegación con pestañas.
  final Map<ChatSection, List<Map<String, dynamic>>> _messagesBySection = {
    ChatSection.cliente: [
      {
        'text': 'Chat con cliente listo para coordinar detalles de entrega.',
        'isUser': false,
      },
    ],
    ChatSection.soporte: [
      {
        'text': '¡Hola! Soy tu asistente de Delivery. ¿En qué puedo ayudarte hoy?',
        'isUser': false,
      },
    ],
    ChatSection.historial: [
      {
        'text': 'Historial vacío. Cuando cierres un chat, aparecerá aquí.',
        'isUser': false,
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: ChatSection.values.length, vsync: this)
      ..addListener(() {
        if (mounted) {
          setState(() {}); // Fuerza el AnimatedSwitcher cuando cambia la pestaña.
        }
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final section = ChatSection.values[_tabController.index];
    if (section == ChatSection.historial) {
      // No permitimos enviar mensajes al historial para mantenerlo como referencia.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un chat activo para enviar mensajes.')),
      );
      return;
    }

    _controller.clear();
    FocusScope.of(context).unfocus();

    setState(() {
      _messagesBySection[section]!.add({'text': trimmed, 'isUser': true});
    });

    if (section == ChatSection.soporte) {
      _generateSupportResponse(trimmed);
    }
  }

  void _generateSupportResponse(String userText) {
    String responseText;
    final lowerCaseText = userText.toLowerCase();

    if (lowerCaseText.contains('hola') || lowerCaseText.contains('saludo')) {
      responseText = '¡Hola! ¿Buscas hacer un pedido o tienes una consulta sobre uno existente?';
    } else if (lowerCaseText.contains('pedido')) {
      responseText =
          'Para hacer un pedido, ve a la pestaña "Productos". Si es sobre un pedido en curso, por favor dame el número.';
    } else if (lowerCaseText.contains('ayuda')) {
      responseText = '¿Necesitas ayuda con el menú, la ubicación o con un repartidor?';
    } else if (lowerCaseText.contains('gracias')) {
      responseText = '¡De nada! Estoy aquí para servirte.';
    } else {
      responseText =
          'Lo siento, aún estoy aprendiendo a responder esa pregunta. Por favor, sé más específico.';
    }

    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() {
        _messagesBySection[ChatSection.soporte]!
            .add({'text': responseText, 'isUser': false});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentSection = ChatSection.values[_tabController.index];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de Mensajes'),
        backgroundColor: Colors.teal.shade400,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Cliente'),
            Tab(text: 'Soporte'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
                      .animate(animation),
                  child: child,
                ),
              ),
              child: _buildMessageList(currentSection),
            ),
          ),
          const Divider(height: 1.0),
          _buildComposer(currentSection, theme),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatSection section) {
    final messages = _messagesBySection[section]!;
    return ListView.builder(
      key: ValueKey('list_$section'),
      reverse: true,
      padding: const EdgeInsets.all(10.0),
      itemCount: messages.length,
      itemBuilder: (_, index) {
        final message = messages[messages.length - 1 - index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment:
            message['isUser'] == true ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: message['isUser'] == true ? Colors.teal.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(15.0),
            ),
            child: Text(
              message['text']?.toString() ?? 'Sin datos',
              style: TextStyle(
                color: message['isUser'] == true ? Colors.teal.shade800 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(ChatSection section, ThemeData theme) {
    if (section == ChatSection.historial) {
      return Container(
        width: double.infinity,
        color: theme.scaffoldBackgroundColor,
        padding: const EdgeInsets.all(16),
        child: const Text(
          'Consulta tus conversaciones previas o cambia de pestaña para continuar hablando.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return IconTheme(
      data: IconThemeData(color: theme.colorScheme.secondary),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            Flexible(
              child: TextField(
                controller: _controller,
                onSubmitted: _handleSubmitted,
                decoration: const InputDecoration.collapsed(
                  hintText: 'Escribe tu mensaje...',
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.teal),
                onPressed: () => _handleSubmitted(_controller.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
