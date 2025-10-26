import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/usuario.dart';
import '../services/database_service.dart';

enum ChatSection { cliente, soporte, historial }

class ChatScreen extends StatefulWidget {
  final ChatSection initialSection;
  const ChatScreen({super.key, this.initialSection = ChatSection.cliente});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<void> _initialLoad;
  final TextEditingController _controller = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd/MM HH:mm');

  Usuario? _currentUser;
  bool _isSending = false;
  String? _loadError;

  final Map<ChatSection, List<ChatConversation>> _conversationsBySection = {
    ChatSection.cliente: [],
    ChatSection.soporte: [],
    ChatSection.historial: [],
  };

  final Map<ChatSection, ChatConversation?> _selectedConversationBySection = {
    ChatSection.cliente: null,
    ChatSection.soporte: null,
    ChatSection.historial: null,
  };

  @override
  void initState() {
    super.initState();
    final initialIndex = ChatSection.values.indexOf(widget.initialSection);
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex)..addListener(_handleTabSelection);
    _initialLoad = _loadConversations();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    }

  Future<void> _loadConversations() async {
    // (Aquí va la lógica para cargar conversaciones desde la API)
  }
  
  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final section = ChatSection.values[_tabController.index];
    final conversation = _selectedConversationBySection[section];
    final user = _currentUser;
    final messenger = ScaffoldMessenger.of(context);

    if (conversation == null || user == null) return;

    setState(() => _isSending = true);

    try {
      final dbService = context.read<DatabaseService>();
      final success = await dbService.enviarMensaje(
        idConversacion: conversation.idConversacion,
        idRemitente: user.idUsuario,
        mensaje: text,
      );

      if (success) {
        _controller.clear();
        _loadConversations();
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('No se pudo enviar el mensaje.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSection = ChatSection.values[_tabController.index];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de Mensajes'),
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Cliente'), Tab(text: 'Soporte'), Tab(text: 'Historial')]),
      ),
      body: FutureBuilder<void>(
        future: _initialLoad,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              if (_loadError != null) Center(child: Text(_loadError!)),
              Expanded(child: _buildSectionContent(currentSection)),
              _buildComposer(currentSection),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionContent(ChatSection section) {
    final conversations = _conversationsBySection[section] ?? [];
    final selectedConversation = _selectedConversationBySection[section];

    if (conversations.isEmpty) {
      return const Center(child: Text('No hay conversaciones en esta sección.'));
    }

    return Row(
      children: [
        SizedBox(
          width: 120,
          child: ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final convo = conversations[index];
              return ListTile(
                title: Text(_conversationLabel(convo)),
                selected: convo.idConversacion == selectedConversation?.idConversacion,
                onTap: () => setState(() => _selectedConversationBySection[section] = convo),
              );
            },
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: selectedConversation == null
              ? const Center(child: Text('Selecciona una conversación.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: selectedConversation.mensajes.length,
                  itemBuilder: (context, index) {
                    final message = selectedConversation.mensajes[index];
                    return _buildMessageBubble(message, isUser: message.idRemitente == _currentUser?.idUsuario);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildComposer(ChatSection section) {
    final conversation = _selectedConversationBySection[section];
    if (conversation == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(hintText: 'Escribe un mensaje...', border: OutlineInputBorder()),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: _isSending ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
            onPressed: _isSending ? null : _sendMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, {required bool isUser}) {
    final bubbleColor = isUser ? Colors.blue.shade100 : Colors.grey.shade200;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = isUser
        ? const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16))
        : const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(color: bubbleColor, borderRadius: radius),
            child: Text(message.mensaje),
          ),
          const SizedBox(height: 2),
          // CORRECCIÓN: Se comprueba si la fecha es nula antes de formatear
          Text(message.fechaEnvio != null ? _dateFormat.format(message.fechaEnvio!) : '', style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  String _conversationLabel(ChatConversation conversation) {
    return conversation.idPedido != null ? 'Pedido #${conversation.idPedido}' : 'Conversación ${conversation.idConversacion}';
  }
}
