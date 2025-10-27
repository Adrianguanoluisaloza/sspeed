import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/session_state.dart';
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
  final TextEditingController _controller = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd/MM HH:mm');

  Usuario? _currentUser;
  bool _isLoading = true;
  bool _isSending = false;
  String? _loadError;

  Map<ChatSection, List<ChatConversation>> _conversations = {
    ChatSection.cliente: [],
    ChatSection.soporte: [],
    ChatSection.historial: [],
  };

  ChatConversation? _selectedConversation;

  @override
  void initState() {
    super.initState();
    final initialIndex = ChatSection.values.indexOf(widget.initialSection);
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex)..addListener(_onTabChanged);
    _initializeChat();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedConversation = null;
      });
    }
  }

  Future<void> _initializeChat() async {
    final session = context.read<SessionController>();
    if (!session.isAuthenticated) {
      setState(() {
        _loadError = "Debes iniciar sesión para ver tus mensajes.";
        _isLoading = false;
      });
      return;
    }
    _currentUser = session.usuario;
    await _loadConversations(context);
  }

  Future<void> _loadConversations(BuildContext currentContext) async {
    if (_currentUser == null) return;

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final dbService = currentContext.read<DatabaseService>();
      final allConversations = await dbService.getConversaciones(_currentUser!.idUsuario);

      if (!mounted) return;

      final newConversations = <ChatSection, List<ChatConversation>>{
        ChatSection.cliente: [],
        ChatSection.soporte: [],
        ChatSection.historial: [],
      };

      for (final convo in allConversations) {
        if (!convo.activa) {
          newConversations[ChatSection.historial]!.add(convo);
        } else if (convo.idAdminSoporte != null) {
          newConversations[ChatSection.soporte]!.add(convo);
        } else {
          newConversations[ChatSection.cliente]!.add(convo);
        }
      }
      setState(() {
        _conversations = newConversations;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _selectedConversation == null || _currentUser == null) return;

    final conversationId = _selectedConversation!.idConversacion;
    final dbService = context.read<DatabaseService>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSending = true);

    try {
      final success = await dbService.enviarMensaje(
        idConversacion: conversationId,
        idRemitente: _currentUser!.idUsuario,
        mensaje: text,
      );

      if (!mounted) return;

      if (success) {
        _controller.clear();
        final updatedMessages = await dbService.getMensajesDeConversacion(conversationId);
        if (!mounted) return;
        setState(() {
          _selectedConversation?.mensajes.clear();
          _selectedConversation?.mensajes.addAll(updatedMessages);
        });
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('No se pudo enviar el mensaje.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Error al enviar: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de Mensajes'),
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Cliente'), Tab(text: 'Soporte'), Tab(text: 'Historial')]),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_loadError!, textAlign: TextAlign.center)));
    }

    final currentSection = ChatSection.values[_tabController.index];
    final conversations = _conversations[currentSection] ?? [];

    if (conversations.isEmpty) {
      return const Center(child: Text('No hay conversaciones en esta sección.'));
    }

    return Row(
      children: [
        _buildConversationList(conversations, currentSection),
        const VerticalDivider(width: 1),
        _buildMessagePane(),
      ],
    );
  }

  Widget _buildConversationList(List<ChatConversation> conversations, ChatSection section) {
    return SizedBox(
      width: 130,
      child: ListView.builder(
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final convo = conversations[index];
          return ListTile(
            title: Text(_conversationLabel(convo), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_dateFormat.format(convo.fechaCreacion), overflow: TextOverflow.ellipsis),
            selected: convo.idConversacion == _selectedConversation?.idConversacion,
            selectedTileColor: Colors.blue.withAlpha(26),
            onTap: () => setState(() => _selectedConversation = convo),
          );
        },
      ),
    );
  }

  Widget _buildMessagePane() {
    if (_selectedConversation == null) {
      return const Expanded(child: Center(child: Text('Selecciona una conversación para ver los mensajes.')));
    }
    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              reverse: true,
              itemCount: _selectedConversation!.mensajes.length,
              itemBuilder: (context, index) {
                final reversedIndex = _selectedConversation!.mensajes.length - 1 - index;
                final message = _selectedConversation!.mensajes[reversedIndex];
                return _buildMessageBubble(message, isUser: message.idRemitente == _currentUser?.idUsuario);
              },
            ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(hintText: 'Escribe un mensaje...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)), contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
            onSubmitted: (_) => _sendMessage(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          icon: _isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
          onPressed: _isSending ? null : _sendMessage,
          style: IconButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
        ),
      ]),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, {required bool isUser}) {
    final bubbleColor = isUser ? Theme.of(context).primaryColor : Colors.grey.shade200;
    final textColor = isUser ? Colors.white : Colors.black87;
    final radius = isUser
        ? const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16))
        : const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16));

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(color: bubbleColor, borderRadius: radius),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // CORRECCIÓN: Se elimina la llamada inválida a `widget()`
          children: [
            Text(message.mensaje, style: TextStyle(color: textColor)),
            const SizedBox(height: 4),
            Text(message.fechaEnvio != null ? _dateFormat.format(message.fechaEnvio!) : '', style: TextStyle(color: isUser ? Colors.white70 : Colors.black54, fontSize: 10)),
          ],
        )
      ),
    );
  }

  String _conversationLabel(ChatConversation conversation) {
    return conversation.idPedido != null ? 'Pedido #${conversation.idPedido}' : 'Conversación ${conversation.idConversacion}';
  }
}
