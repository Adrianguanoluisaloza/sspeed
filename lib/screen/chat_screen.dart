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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Centro de Mensajes', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withAlpha(26),
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.primaryColor,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: theme.primaryColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Cliente'),
            Tab(text: 'Soporte'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }


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
      });
    }
  }

  Future<void> _initializeChat() async {
    final session = context.read<SessionController>();
    if (!mounted) return;

    if (!session.isAuthenticated) {
      setState(() {
        _loadError = "Debes iniciar sesiÃ³n para ver tus mensajes.";
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
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
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
    if (lower.contains('hola')) return 'Â¡Hola! Â¿CÃ³mo puedo ayudarte?';
    if (lower.contains('problema') || lower.contains('error')) return 'Lamentamos el problema. Â¿Puedes dar mÃ¡s detalles?';
    if (lower.contains('gracias')) return 'Â¡Con gusto! Si necesitas algo mÃ¡s, estoy aquÃ­.';
    return 'Gracias por tu mensaje. Un agente lo revisarÃ¡ pronto.';
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _loadError!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final currentSection = ChatSection.values[_tabController.index];
    final conversations = _conversations[currentSection] ?? [];

    if (_selectedConversation == null && conversations.isNotEmpty) {
      _selectedConversation = conversations.first;
    }

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
      return const Expanded(
        child: Center(
          child: Text('Selecciona una conversaciÃ³n para ver los mensajes'),
        ),
      );
    }

    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              reverse: true,
              itemCount: _selectedConversation!.mensajes.length,
              itemBuilder: (context, index) {
                final reversedIndex = _selectedConversation!.mensajes.length - 1 - index;
                final message = _selectedConversation!.mensajes[reversedIndex];
                final isUser = message.idRemitente == _currentUser?.idUsuario;
                return _buildMessageBubble(message, isUser: isUser);
              },
            ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 5,
            color: Colors.black.withAlpha(8),
          )
        ],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  fillColor: Colors.grey.shade100,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onSubmitted: _isSending ? null : (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: _isSending
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: _isSending ? null : _sendMessage,
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, {required bool isUser}) {
    final theme = Theme.of(context);
    final bubbleColor = isUser ? theme.primaryColor : const Color(0xFFEFEFEF);
    final textColor = isUser ? Colors.white : Colors.black87;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final radius = isUser
        ? const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
        bottomLeft: Radius.circular(20),
        bottomRight: Radius.circular(5))
        : const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
        bottomRight: Radius.circular(20),
        bottomLeft: Radius.circular(5));

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(color: bubbleColor, borderRadius: radius),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(message.mensaje, style: TextStyle(color: textColor, fontSize: 16)),
            const SizedBox(height: 5),
            Text(
              message.fechaEnvio != null ? _dateFormat.format(message.fechaEnvio!) : 'Enviando...',
              style: TextStyle(color: isUser ? Colors.white70 : Colors.black54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChatView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 120, color: Colors.grey.shade300),
            const SizedBox(height: 24),
            Text(
              'No hay chats aquÃ­',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando tengas una conversaciÃ³n, la verÃ¡s en esta secciÃ³n.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationList(List<ChatConversation> conversations, ChatSection section) {
    return Container(
      width: 140,
      color: const Color(0xFFF7F7F7),
      child: ListView.builder(
        itemCount: conversations.length,
        itemBuilder: (context, index) {
          final convo = conversations[index];
          final isSelected = convo.idConversacion == _selectedConversation?.idConversacion;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            title: Text(
              _conversationLabel(convo),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _dateFormat.format(convo.fechaCreacion),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            selected: isSelected,
            selectedTileColor: Theme.of(context).primaryColor.withAlpha(26),
            onTap: () => setState(() => _selectedConversation = convo),
          );
        },
      ),
    );
  }

  String _conversationLabel(ChatConversation conversation) {
    return conversation.idPedido != null ? 'Pedido #${conversation.idPedido}' : 'ConversaciÃ³n ${conversation.idConversacion}';
  }
}
