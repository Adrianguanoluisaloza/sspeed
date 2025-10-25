import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/session_state.dart';
import '../models/usuario.dart';
import '../services/database_service.dart';

/// Secciones disponibles en el centro de mensajería.
enum ChatSection { cliente, soporte, historial }

class ChatScreen extends StatefulWidget {
  final ChatSection initialSection;
  const ChatScreen({super.key, this.initialSection = ChatSection.cliente});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<void> _initialLoad;
  final TextEditingController _controller = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd/MM HH:mm');

  Usuario? _currentUser;
  bool _hasLoadedOnce = false;
  bool _isSending = false;
  String? _loadError;

  Map<ChatSection, List<ChatConversation>> _conversationsBySection = {
    ChatSection.cliente: <ChatConversation>[],
    ChatSection.soporte: <ChatConversation>[],
    ChatSection.historial: <ChatConversation>[],
  };

  Map<ChatSection, ChatConversation?> _selectedConversationBySection = {
    ChatSection.cliente: null,
    ChatSection.soporte: null,
    ChatSection.historial: null,
  };

  @override
  void initState() {
    super.initState();
    final initialIndex = ChatSection.values.indexOf(widget.initialSection);
    _tabController = TabController(
      length: ChatSection.values.length,
      vsync: this,
      initialIndex: initialIndex,
    )..addListener(() {
        if (!mounted) return;
        final section = ChatSection.values[_tabController.index];
        final selected = _selectedConversationBySection[section];
        if (selected == null) {
          final list = _conversationsBySection[section] ?? [];
          if (list.isNotEmpty) {
            setState(() {
              _selectedConversationBySection[section] = list.first;
            });
          } else {
            setState(() {});
          }
        } else {
          setState(() {});
        }
      });
    _initialLoad = _loadConversations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    try {
      final sessionController = context.read<SessionController>();
      final user = sessionController.usuario;
      _currentUser = user;

      if (user.isGuest) {
        _setupGuestSamples(user);
        if (!mounted) return;
        setState(() {
          _loadError = null;
          _hasLoadedOnce = true;
        });
        return;
      }

      final dbService = context.read<DatabaseService>();
      final conversations = await dbService.getConversaciones(user.idUsuario);

      final grouped = {
        ChatSection.cliente: <ChatConversation>[],
        ChatSection.soporte: <ChatConversation>[],
        ChatSection.historial: <ChatConversation>[],
      };

      for (final conversation in conversations) {
        final messages =
            await dbService.getMensajesDeConversacion(conversation.idConversacion);
        final lastMessage = messages.isNotEmpty ? messages.last : null;
        final updatedConversation = conversation.copyWith(
          mensajes: messages,
          ultimoMensaje: lastMessage?.mensaje ?? conversation.ultimoMensaje,
          fechaActualizacion:
              lastMessage?.fechaEnvio ?? conversation.fechaActualizacion,
        );
        final section = _categorizeConversation(updatedConversation, user);
        grouped[section]!.add(updatedConversation);
      }

      grouped[ChatSection.historial] = [
        ...grouped[ChatSection.cliente]!,
        ...grouped[ChatSection.soporte]!,
      ]..sort((a, b) {
          final aDate =
              a.fechaActualizacion ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate =
              b.fechaActualizacion ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });

      if (!mounted) return;
      setState(() {
        _conversationsBySection = grouped;
        _selectedConversationBySection = {
          for (final section in ChatSection.values)
            section: grouped[section]!.isNotEmpty ? grouped[section]!.first : null,
        };
        _loadError = null;
        _hasLoadedOnce = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'No fue posible cargar tus conversaciones.';
        _hasLoadedOnce = true;
      });
    }
  }

  void _setupGuestSamples(Usuario user) {
    final now = DateTime.now();

    ChatConversation buildConversation(
      ChatSection section,
      List<Map<String, dynamic>> rawMessages,
    ) {
      final messages = rawMessages.asMap().entries.map((entry) {
        final isUser = entry.value['isUser'] == true;
        return ChatMessage(
          idMensaje: entry.key + 1,
          idConversacion: section.index,
          idRemitente: isUser ? user.idUsuario : 0,
          mensaje: entry.value['text']?.toString() ?? 'Sin datos',
          fechaEnvio: now.subtract(Duration(minutes: rawMessages.length - entry.key)),
          remitenteNombre: isUser ? user.nombre : 'Soporte',
        );
      }).toList();

      return ChatConversation(
        idConversacion: section.index,
        idCliente: section == ChatSection.cliente ? user.idUsuario : null,
        idDelivery: section == ChatSection.cliente ? 1 : null,
        idAdminSoporte: section == ChatSection.soporte ? 1 : null,
        ultimoMensaje: messages.isNotEmpty ? messages.last.mensaje : null,
        fechaActualizacion: messages.isNotEmpty ? messages.last.fechaEnvio : now,
        mensajes: messages,
      );
    }

    final clienteSamples = buildConversation(ChatSection.cliente, [
      {
        'text': 'Hola, ¿qué tal va mi pedido?',
        'isUser': true,
      },
      {
        'text': 'Tu pedido está en preparación y saldrá en breve.',
        'isUser': false,
      },
    ]);

    final soporteSamples = buildConversation(ChatSection.soporte, [
      {
        'text': 'Bienvenido al centro de soporte. ¿En qué podemos ayudarte?',
        'isUser': false,
      },
      {
        'text': 'Solo estoy explorando la app en modo invitado.',
        'isUser': true,
      },
    ]);

    final historial = [clienteSamples, soporteSamples];

    _conversationsBySection = {
      ChatSection.cliente: [clienteSamples],
      ChatSection.soporte: [soporteSamples],
      ChatSection.historial: historial,
    };

    _selectedConversationBySection = {
      ChatSection.cliente: clienteSamples,
      ChatSection.soporte: soporteSamples,
      ChatSection.historial: historial.isNotEmpty ? historial.first : null,
    };
  }

  ChatSection _categorizeConversation(
      ChatConversation conversation, Usuario user) {
    if (conversation.idAdminSoporte != null &&
        conversation.idAdminSoporte != 0) {
      if (user.rol == 'admin' || conversation.idAdminSoporte == user.idUsuario) {
        return ChatSection.soporte;
      }
    }

    final deliveryMatches = conversation.idDelivery != null &&
        conversation.idDelivery != 0 &&
        conversation.idDelivery == user.idUsuario;
    final clientMatches = conversation.idCliente != null &&
        conversation.idCliente != 0 &&
        conversation.idCliente == user.idUsuario;

    if (deliveryMatches || clientMatches) {
      return ChatSection.cliente;
    }

    if (conversation.idAdminSoporte != null) {
      return ChatSection.soporte;
    }

    return ChatSection.historial;
  }

  String _conversationLabel(ChatConversation conversation) {
    if (conversation.idPedido != null && conversation.idPedido! > 0) {
      return 'Pedido #${conversation.idPedido}';
    }
    if (conversation.idConversacion > 0) {
      return 'Conversación ${conversation.idConversacion}';
    }
    return 'Conversación';
  }

  @override
  Widget build(BuildContext context) {
    final currentSection = ChatSection.values[_tabController.index];

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
      body: FutureBuilder<void>(
        future: _initialLoad,
        builder: (context, snapshot) {
          if (!_hasLoadedOnce &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              if (_loadError != null)
                Container(
                  width: double.infinity,
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _loadError!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _initialLoad = _loadConversations();
                          });
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: _buildSectionContent(currentSection),
                ),
              ),
              _buildComposer(currentSection),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionContent(ChatSection section) {
    final conversations = _conversationsBySection[section] ?? [];
    if (conversations.isEmpty) {
      return _buildEmptyState(section);
    }

    if (section == ChatSection.historial) {
      return ListView.separated(
        key: const ValueKey('historial_list'),
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final conversation = conversations[index];
          final subtitle = conversation.ultimoMensaje ?? 'Sin mensajes recientes';
          final updated = conversation.fechaActualizacion != null
              ? _dateFormat.format(conversation.fechaActualizacion!)
              : 'Sin fecha';
          return Card(
            child: ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(_conversationLabel(conversation)),
              subtitle: Text('$subtitle\nActualizado: $updated'),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: conversations.length,
      );
    }

    final selectedConversation = _selectedConversationBySection[section];

    return Column(
      key: ValueKey('section_${section.name}'),
      children: [
        if (conversations.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'Conversación',
                border: OutlineInputBorder(),
              ),
              value: selectedConversation?.idConversacion,
              items: conversations
                  .map(
                    (conversation) => DropdownMenuItem(
                      value: conversation.idConversacion,
                      child: Text(_conversationLabel(conversation)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedConversationBySection[section] = conversations.firstWhere(
                    (conversation) => conversation.idConversacion == value,
                    orElse: () => selectedConversation ?? conversations.first,
                  );
                });
              },
            ),
          ),
        Expanded(
          child: selectedConversation == null
              ? _buildEmptyState(section)
              : _buildMessageList(selectedConversation),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ChatSection section) {
    final theme = Theme.of(context);
    final icon = section == ChatSection.historial
        ? Icons.archive_outlined
        : Icons.chat_outlined;
    final message = section == ChatSection.historial
        ? 'No hay conversaciones anteriores para mostrar.'
        : 'No tienes conversaciones disponibles en esta sección.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ChatConversation conversation) {
    final messages = [...conversation.mensajes]
      ..sort((a, b) {
        final aDate = a.fechaEnvio ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.fechaEnvio ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });

    return ListView.builder(
      key: ValueKey('conversation_${conversation.idConversacion}'),
      padding: const EdgeInsets.all(12.0),
      itemCount: messages.length,
      itemBuilder: (_, index) {
        final message = messages[index];
        final isUser = _currentUser?.idUsuario == message.idRemitente;
        return _buildMessageBubble(message, isUser: isUser);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, {required bool isUser}) {
    final bubbleColor = isUser ? Colors.teal.shade100 : Colors.grey.shade200;
    final textColor = isUser ? Colors.teal.shade800 : Colors.black87;
    final time = message.fechaEnvio != null
        ? _dateFormat.format(message.fechaEnvio!)
        : 'Sin fecha';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Column(
                crossAxisAlignment:
                    isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (message.remitenteNombre != null && message.remitenteNombre!.isNotEmpty)
                    Text(
                      message.remitenteNombre!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  Text(
                    message.mensaje,
                    style: TextStyle(color: textColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(ChatSection section) {
    final user = _currentUser;
    if (section == ChatSection.historial) {
      return Container(
        width: double.infinity,
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.all(16),
        child: const Text(
          'Revisa el historial de conversaciones o cambia de pestaña para seguir chateando.',
          textAlign: TextAlign.center,
        ),
      );
    }

    if (user == null) {
      return const SizedBox.shrink();
    }

    if (user.isGuest) {
      return Container(
        width: double.infinity,
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.all(16),
        child: const Text(
          'Inicia sesión para continuar la conversación con nuestros agentes.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final selectedConversation = _selectedConversationBySection[section];
    if (selectedConversation == null) {
      return Container(
        width: double.infinity,
        color: Theme.of(context).scaffoldBackgroundColor,
        padding: const EdgeInsets.all(16),
        child: const Text(
          'Selecciona una conversación activa para enviar mensajes.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return SafeArea(
      top: false,
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
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send, color: Colors.teal),
                onPressed:
                    _isSending ? null : () => _handleSubmitted(_controller.text),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmitted(String text) async {
    if (_isSending) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final user = _currentUser;
    if (user == null || user.isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para enviar mensajes.')),
      );
      return;
    }

    final section = ChatSection.values[_tabController.index];
    final conversation = _selectedConversationBySection[section];
    if (conversation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una conversación para continuar.')),
      );
      return;
    }

    _controller.clear();
    FocusScope.of(context).unfocus();

    setState(() => _isSending = true);
    final dbService = context.read<DatabaseService>();
    try {
      final success = await dbService.enviarMensaje(
        idConversacion: conversation.idConversacion,
        idRemitente: user.idUsuario,
        mensaje: trimmed,
      );

      if (!mounted) return;

      if (success) {
        await _reloadConversation(section, conversation.idConversacion);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar el mensaje.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _reloadConversation(ChatSection section, int conversationId) async {
    final user = _currentUser;
    if (user == null || user.isGuest) return;

    final dbService = context.read<DatabaseService>();
    final messages = await dbService.getMensajesDeConversacion(conversationId);

    if (!mounted) return;

    setState(() {
      final list = _conversationsBySection[section] ?? [];
      final index = list.indexWhere((c) => c.idConversacion == conversationId);
      if (index != -1) {
        final lastMessage = messages.isNotEmpty ? messages.last : null;
        final updated = list[index].copyWith(
          mensajes: messages,
          ultimoMensaje: lastMessage?.mensaje ?? list[index].ultimoMensaje,
          fechaActualizacion:
              lastMessage?.fechaEnvio ?? list[index].fechaActualizacion,
        );
        list[index] = updated;
        _selectedConversationBySection[section] = updated;
      }

      _conversationsBySection[ChatSection.historial] = [
        ..._conversationsBySection[ChatSection.cliente]!,
        ..._conversationsBySection[ChatSection.soporte]!,
      ]..sort((a, b) {
          final aDate =
              a.fechaActualizacion ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate =
              b.fechaActualizacion ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
    });
  }
}
