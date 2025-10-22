
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, dynamic>> _messages = [
    {'text': '¡Hola! Soy tu asistente de Delivery. ¿En qué puedo ayudarte hoy?', 'isUser': false},
  ];
  final TextEditingController _controller = TextEditingController();

  void _handleSubmitted(String text) {
    _controller.clear();
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({'text': text, 'isUser': true});
    });

    // Simulación de respuesta del chatbot
    _generateBotResponse(text);
  }

  void _generateBotResponse(String userText) {
    String responseText;
    final lowerCaseText = userText.toLowerCase();

    if (lowerCaseText.contains('hola') || lowerCaseText.contains('saludo')) {
      responseText = '¡Hola! ¿Buscas hacer un pedido o tienes una consulta sobre uno existente?';
    } else if (lowerCaseText.contains('pedido')) {
      responseText = 'Para hacer un pedido, ve a la pestaña "Productos". Si es sobre un pedido en curso, por favor dame el número.';
    } else if (lowerCaseText.contains('ayuda')) {
      responseText = '¿Necesitas ayuda con el menú, la ubicación, o con un repartidor?';
    } else if (lowerCaseText.contains('gracias')) {
      responseText = '¡De nada! Estoy aquí para servirte.';
    } else {
      responseText = 'Lo siento, aún estoy aprendiendo a responder esa pregunta. Por favor, sé más específico.';
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _messages.add({'text': responseText, 'isUser': false});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soporte Chatbot'),
        backgroundColor: Colors.teal.shade400,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(10.0),
              itemCount: _messages.length,
              itemBuilder: (_, int index) => _buildMessage(_messages[_messages.length - 1 - index]),
            ),
          ),
          const Divider(height: 1.0),
          _buildTextComposer(),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: message['isUser']
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: message['isUser'] ? Colors.teal.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(15.0),
            ),
            child: Text(
              message['text'],
              style: TextStyle(
                color: message['isUser'] ? Colors.teal.shade800 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
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
