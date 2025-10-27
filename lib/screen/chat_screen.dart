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
  final DateFormat _dateFormat = DateFormat('dd MMM, HH:mm');

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
  final ScrollController _scrollController = ScrollController();

  final Color _brandColor = const Color(0xFFF97316);
  final Color _brandLightColor = const Color(0xFFFFEFE5);

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
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedConversation = null;
        final currentSection = ChatSection.values[_tabController.index];
        final conversationsForSection = _conversations[currentSection] ?? [];
        if (conversationsForSection.isNotEmpty) {
          _selectedConversation = conversationsForSection.first;
        }
      });
    }
  }

  Future<void> _initializeChat() async {
    final session = context.read<SessionController>();
    if (!mounted) return;

    if (!session.isAuthenticated) {
      setState(() {
        _loadError = "Debes iniciar sesión para ver tus mensajes.";
        _isLoading = false;
      });
      return;
    }
    _currentUser = session.usuario;
    await _loadConversations();
  }

  Future<void> _loadConversations() async {
    if (_currentUser == null || !mounted) return;

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final dbService = context.read<DatabaseService>();
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

      if (newConversations[ChatSection.soporte]!.isEmpty) {
        final fakeConvo = ChatConversation(
          idConversacion: DateTime.now().millisecondsSinceEpoch,
          idCliente: _currentUser?.idUsuario,
          idAdminSoporte: 999999,
          activa: true,
          fechaCreacion: DateTime.now(),
          mensajes: [],
        );
        newConversations[ChatSection.soporte]!.add(fakeConvo);
      }

      setState(() {
        _conversations = newConversations;
        _isLoading = false;
        final currentSection = ChatSection.values[_tabController.index];
        final conversationsForSection = _conversations[currentSection] ?? [];
        if (_selectedConversation == null && conversationsForSection.isNotEmpty) {
          _selectedConversation = conversationsForSection.first;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = "Error al cargar: ${e.toString()}";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _selectedConversation == null || _currentUser == null || !mounted) return;

    final dbService = context.read<DatabaseService>();
    final messenger = ScaffoldMessenger.of(context);
    final conversationId = _selectedConversation!.idConversacion;

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
        if (mounted) {
          setState(() {
            _selectedConversation?.mensajes.clear();
            _selectedConversation?.mensajes.addAll(updatedMessages);
          });

          final isSoporte = _selectedConversation?.idAdminSoporte != null;
          if (isSoporte) {
            await Future.delayed(const Duration(seconds: 1));
            final respuesta = _respuestaAutomatica(text);

            if (!mounted) return;
            final botMessage = ChatMessage(
              idMensaje: DateTime.now().millisecondsSinceEpoch,
              idConversacion: conversationId,
              idRemitente: 999999,
              mensaje: respuesta,
              fechaEnvio: DateTime.now(),
              remitenteNombre: 'Soporte Bot',
            );

            setState(() {
              _selectedConversation?.mensajes.add(botMessage);
            });

            Timer(const Duration(milliseconds: 100), () {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
              }
            });
          }
        }
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('No se pudo enviar el mensaje.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Error al enviar: ${e.toString()}'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _respuestaAutomatica(String mensaje) {
    final lower = mensaje.toLowerCase();
    if (lower.contains('hola')) return '¡Hola! ¿Cómo puedo ayudarte?';
    if (lower.contains('problema') || lower.contains('error')) return 'Lamentamos el problema. ¿Puedes dar más detalles?';
    if (lower.contains('gracias')) return '¡Con gusto! Si necesitas algo más, estoy aquí.';
    return 'Gracias por tu mensaje. Un agente lo revisará pronto.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Centro de Mensajes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withAlpha(26),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _brandColor,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: _brandColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [Tab(text: 'Cliente'), Tab(text: 'Soporte'), Tab(text: 'Historial')],
        ),
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
      return _buildEmptyChatView();
    }

    return Row(
      children: [
        _buildConversationList(conversations, currentSection),
        const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE0E0E0)),
        _buildMessagePane(),
      ],
    );
  }

  Widget _buildMessagePane() {
    if (_selectedConversation == null) {
      return const Expanded(child: Center(child: Text('Selecciona una conversación para ver los mensajes')));
    }
    return Expanded(child: Column(children: [Expanded(child: ListView.builder(controller: _scrollController, padding: const EdgeInsets.all(16.0), reverse: true, itemCount: _selectedConversation!.mensajes.length, itemBuilder: (context, index) {
      final reversedIndex = _selectedConversation!.mensajes.length - 1 - index;
      final message = _selectedConversation!.mensajes[reversedIndex];
      return _buildMessageBubble(message, isUser: message.idRemitente == _currentUser?.idUsuario);
    })), _buildComposer()]));
  }

  Widget _buildComposer() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [BoxShadow(offset: const Offset(0, -2), blurRadius: 8, color: Colors.black.withAlpha(15))],
      ),
      child: SafeArea(
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: Container(decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(25)), child: TextField(controller: _controller, decoration: const InputDecoration(hintText: 'Escribe un mensaje...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12)), onSubmitted: _isSending ? null : (_) => _sendMessage()))), const SizedBox(width: 10), IconButton(icon: _isSending ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary)) : Icon(Icons.send_rounded, color: theme.colorScheme.onPrimary), onPressed: _isSending ? null : _sendMessage, style: IconButton.styleFrom(backgroundColor: _brandColor, shape: const CircleBorder(), padding: const EdgeInsets.all(12)))]),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, {required bool isUser}) {
    final bubbleColor = isUser ? _brandColor : const Color(0xFFEFEFEF);
    final textColor = isUser ? Colors.white : Colors.black87;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final borderRadius = isUser ? const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(4)) : const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4));
    return Align(alignment: alignment, child: Container(margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0), padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0), decoration: BoxDecoration(color: bubbleColor, borderRadius: borderRadius), constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7), child: Column(crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [Text(message.mensaje, style: TextStyle(color: textColor, fontSize: 16)), const SizedBox(height: 4), Text(message.fechaEnvio != null ? _dateFormat.format(message.fechaEnvio!) : 'Enviando...', style: TextStyle(color: isUser ? Colors.white70 : Colors.black54, fontSize: 10))])));
  }

  Widget _buildEmptyChatView() {
    return Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.forum_outlined, size: 120, color: Colors.grey.shade300), const SizedBox(height: 24), Text('No hay chats aquí', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text('Cuando tengas una conversación, la verás en esta sección.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600))])));
  }

  Widget _buildConversationList(List<ChatConversation> conversations, ChatSection section) {
    return Container(
      width: 250,
      color: const Color(0xFFF7F7F7),
      child: ListView.builder(
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final convo = conversations[index];
          final isSelected = convo.idConversacion == _selectedConversation?.idConversacion;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(backgroundColor: _brandLightColor, child: Icon(section == ChatSection.soporte ? Icons.support_agent : Icons.person_outline, color: _brandColor, size: 20)),
            title: Text(_conversationLabel(convo), style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? _brandColor : Colors.black87, fontSize: 15), overflow: TextOverflow.ellipsis),
            subtitle: Text(_dateFormat.format(convo.fechaCreacion), overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            trailing: section == ChatSection.cliente && convo.idConversacion % 2 == 0 ? Container(padding: const EdgeInsets.all(5)) : null,
            onTap: () => setState(() => _selectedConversation = convo),
            selected: isSelected,
            selectedTileColor: Colors.white,
          );
        },
      ),
    );
  }

  String _conversationLabel(ChatConversation conversation) {
    if (conversation.idAdminSoporte != null) return 'Soporte';
    return conversation.idPedido != null ? 'Pedido #${conversation.idPedido}' : 'Conversación #${conversation.idConversacion}';
  }
}
