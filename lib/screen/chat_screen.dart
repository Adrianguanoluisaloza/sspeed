import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../models/usuario.dart';
import '../models/session_state.dart';
import '../services/database_service.dart';
import '../services/gemini_service.dart';

// Sección de chat para organizar las conversaciones
enum ChatSection {
  cliente,
  soporte,
  historial,
}

class ChatScreen extends StatefulWidget {
  final ChatSection initialSection;
  const ChatScreen({Key? key, this.initialSection = ChatSection.cliente}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSending = false;
  final DateFormat _dateFormat = DateFormat('HH:mm');

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _selectedConversation == null || _currentUser == null || !mounted) return;

    final conversation = _selectedConversation!;
    final dbService = context.read<DatabaseService>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSending = true);

    try {
      final tempMessage = ChatMessage(
        idMensaje: -DateTime.now().millisecondsSinceEpoch,
        idConversacion: conversation.idConversacion,
        idRemitente: _currentUser!.idUsuario,
        mensaje: text,
        fechaEnvio: DateTime.now(),
        remitenteNombre: _currentUser!.nombre,
      );

      setState(() {
        conversation.mensajes.add(tempMessage);
        _controller.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

      await dbService.enviarMensaje(
        idConversacion: conversation.idConversacion,
        idRemitente: _currentUser!.idUsuario,
        mensaje: text,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al enviar: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => conversation.mensajes.removeWhere((m) => m.idMensaje < 0));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
  late final TabController _tabController;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final Color _brandColor = const Color(0xFFF97316);
  final Color _brandLightColor = const Color(0xFFFFEFE5);
  GeminiService? _geminiService;
  bool _isBotTyping = false;

  Map<ChatSection, List<ChatConversation>> _conversations = {
    ChatSection.cliente: [],
    ChatSection.soporte: [],
    ChatSection.historial: [],
  };
  ChatConversation? _selectedConversation;
  Usuario? _currentUser;
  bool _isLoading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    final initialIndex = ChatSection.values.indexOf(widget.initialSection);
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex)..addListener(_onTabChanged);
    _initializeChat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _geminiService ??= context.read<GeminiService>();
  }

  @override


// ...existing code...

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
        _loadError = 'Debes iniciar sesión para ver tus mensajes.';
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

      setState(() {
        _conversations = newConversations;
        _isLoading = false;
        final currentSection = ChatSection.values[_tabController.index];
        final conversationsForSection = _conversations[currentSection] ?? [];
        if (conversationsForSection.isEmpty) {
          _selectedConversation = null;
          return;
        }
        final currentId = _selectedConversation?.idConversacion;
        if (currentId == null) {
          _selectedConversation = conversationsForSection.first;
        } else {
          _selectedConversation = conversationsForSection.firstWhere(
            (c) => c.idConversacion == currentId,
            orElse: () => conversationsForSection.first,
          );
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: false));
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = "Error al cargar: ${e.toString()}";
          _isLoading = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final bool isCompact = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F6FA),
      drawer: isCompact ? _buildConversationDrawer() : null,
      appBar: AppBar(
        elevation: 0.6,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Soporte en linea',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 2),
            Text(
              'Estamos disponibles para ayudarte',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar conversaciones',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _loadConversations,
          ),
          if (isCompact)
            IconButton(
              tooltip: 'Ver conversaciones',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: _brandColor,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                indicator: BoxDecoration(
                  color: _brandColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                tabs: const [
                  Tab(text: 'Cliente'),
                  Tab(text: 'Asistente'),
                  Tab(text: 'Historial'),
                ],
              ),
            ),
          ),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_loadError!, textAlign: TextAlign.center),
        ),
      );
    }

    final currentSection = ChatSection.values[_tabController.index];
    final conversations = _conversations[currentSection] ?? [];

    if (_selectedConversation == null && conversations.isNotEmpty) {
      _selectedConversation = conversations.first;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 900;

        if (conversations.isEmpty) {
          return _buildEmptyChatView(isWide: isWide);
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: isWide
              ? _buildDesktopLayout(conversations, currentSection)
              : _buildMobileLayout(conversations, currentSection),
        );
      },
    );
  }

  Widget _buildDesktopLayout(List<ChatConversation> conversations, ChatSection section) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 320, child: _buildConversationPanel(conversations, section)),
        const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE0E0E0)),
        Expanded(
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildConversationHeader(showPicker: false),
                const Divider(height: 1),
                Expanded(child: _buildMessageArea()),
                _buildComposer(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(List<ChatConversation> conversations, ChatSection section) {
    return Column(
      children: [
        _buildConversationHeader(
          showPicker: true,
          onShowPicker: () => _openConversationPicker(conversations, section),
        ),
        Expanded(
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                Expanded(child: _buildMessageArea()),
                _buildComposer(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConversationHeader({required bool showPicker, VoidCallback? onShowPicker}) {
    final conversation = _selectedConversation;
    final theme = Theme.of(context);

    if (conversation == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        alignment: Alignment.centerLeft,
        child: Text(
          'Selecciona una conversacion',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      );
    }

    final bool isBot = conversation.idAdminSoporte != null;
    final subtitle = _conversationSubtitle(conversation, isBot: isBot, includePreview: false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: Colors.white,
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: isBot ? _brandLightColor : const Color(0xFFE3F2FD),
            child: Icon(
              isBot ? Icons.smart_toy : Icons.person_outline,
              color: _brandColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _conversationLabel(conversation),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (showPicker)
            IconButton(
              tooltip: 'Cambiar de conversacion',
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: onShowPicker,
            ),
        ],
      ),
    );
  }

  Widget _buildMessageArea() {
    return Stack(
      children: [
        Positioned.fill(child: _buildMessageList()),
        if (_isBotTyping && (_selectedConversation?.idAdminSoporte != null))
          Align(
            alignment: Alignment.bottomLeft,
            child: _buildTypingIndicator(),
          ),
      ],
    );
  }

  Widget _buildMessageList() {
    final conversation = _selectedConversation;
    if (conversation == null || conversation.mensajes.isEmpty) {
      return _buildEmptyMessagesState();
    }

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: false,
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        physics: const BouncingScrollPhysics(),
        itemCount: conversation.mensajes.length,
        itemBuilder: (context, index) {
          final reversedIndex = conversation.mensajes.length - 1 - index;
          final message = conversation.mensajes[reversedIndex];
          return _buildMessageBubble(message, isUser: message.idRemitente == _currentUser?.idUsuario);
        },
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.bottomLeft,
      child: _buildMessageBubble( // Se crea el objeto directamente aquí
        ChatMessage(
          idMensaje: -1, // ID especial para identificarlo
          idConversacion: 0,
          idRemitente: 0,
          mensaje: '...',
          fechaEnvio: DateTime.now(),
          remitenteNombre: 'Asistente virtual',
        ),
        isUser: false, // Se mantiene el parámetro
      ),
    );
  }

  Widget _buildEmptyMessagesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mark_chat_unread_outlined, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 18),
            Text(
              'Aun no hay mensajes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Escribe tu primera pregunta y nuestro asistente te respondera de inmediato.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Adjuntar archivo',
              icon: const Icon(Icons.add_circle_outline),
              color: _brandColor,
              onPressed: () {},
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Escribe tu mensaje...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: _isSending ? null : (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _isSending ? null : _sendMessage,
              icon: _isSending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 22, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: _brandColor,
                padding: const EdgeInsets.all(14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, {required bool isUser}) {
    if (message.idMensaje == -1) { // Es el indicador de "escribiendo..."
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              topRight: Radius.circular(22),
              bottomRight: Radius.circular(22),
              bottomLeft: Radius.circular(8),
            ),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: _TypingDots(brandColor: _brandColor),
        ),
      );
    }

    final bool isBot = !isUser;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final BorderRadius borderRadius = isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
            bottomLeft: Radius.circular(22),
            bottomRight: Radius.circular(8),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
            bottomRight: Radius.circular(22),
            bottomLeft: Radius.circular(8),
          );

    final BoxDecoration decoration = BoxDecoration(
      color: isUser ? _brandColor : const Color(0xFFF8F9FA),
      borderRadius: borderRadius,
      border: isUser
          ? null
          : Border.all(color: Colors.grey.shade200),
    );

    final String? timestamp = message.fechaEnvio != null ? _dateFormat.format(message.fechaEnvio!) : null;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: decoration,
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isUser && (message.remitenteNombre?.isNotEmpty ?? false)) ...[
                Text(
                  message.remitenteNombre!,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                message.mensaje,
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF1F2937),
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isBot) ...[
                    Icon(Icons.smart_toy, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    timestamp ?? 'Enviando...',
                    style: TextStyle(
                      color: isUser ? Colors.white70 : Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChatView({bool isWide = true}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.support_agent, size: isWide ? 128 : 96, color: Colors.grey.shade300),
            const SizedBox(height: 24),
            Text(
              'Aun no hay conversaciones',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700) ??
                  const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando inicies una conversacion veras el historial en esta seccion.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationPanel(List<ChatConversation> conversations, ChatSection section) {
    return Container(
      color: const Color(0xFFF8F8FB),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                Icon(Icons.chat_outlined, color: _brandColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Conversaciones',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _conversationListView(conversations, section),
          ),
        ],
      ),
    );
  }

  Widget _conversationListView(
    List<ChatConversation> conversations,
    ChatSection section, {
    EdgeInsets padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
  }) {
    return ListView.separated(
      padding: padding,
      itemCount: conversations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final convo = conversations[index];
        final isSelected = convo.idConversacion == _selectedConversation?.idConversacion;
        return _conversationTile(
          convo,
          section,
          isSelected,
          onTap: () => _selectConversation(convo),
        );
      },
    );
  }

  Widget _conversationTile(
    ChatConversation conversation,
    ChatSection section,
    bool isSelected, {
    VoidCallback? onTap,
    bool showPreview = true,
  }) {
    final subtitle = _conversationSubtitle(
      conversation,
      isBot: conversation.idAdminSoporte != null,
      includePreview: showPreview,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? _brandColor.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? _brandColor.withValues(alpha: 0.35)
                : Colors.grey.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _brandLightColor,
              child: Icon(section == ChatSection.soporte ? Icons.smart_toy : Icons.person_outline,
                  color: _brandColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _conversationLabel(conversation),
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _openConversationPicker(List<ChatConversation> conversations, ChatSection section) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 48,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Tus conversaciones',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700) ??
                        const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: conversations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final convo = conversations[index];
                      final isSelected = convo.idConversacion == _selectedConversation?.idConversacion;
                      return _conversationTile(
                        convo,
                        section,
                        isSelected,
                        onTap: () {
                          Navigator.of(context).pop();
                          _selectConversation(convo);
                        },
                        showPreview: false,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Drawer _buildConversationDrawer() {
    final currentSection = ChatSection.values[_tabController.index];
    final conversations = _conversations[currentSection] ?? [];

    return Drawer(
      child: SafeArea(
        child: conversations.isEmpty
            ? _buildEmptyChatView(isWide: false)
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline, color: _brandColor, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Conversaciones',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _conversationListView(
                      conversations,
                      currentSection,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _selectConversation(ChatConversation conversation) {
    if (_selectedConversation?.idConversacion == conversation.idConversacion) {
      if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
        Navigator.of(context).pop();
      }
      return;
    }

    setState(() => _selectedConversation = conversation);

    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    const target = 0.0;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  String _conversationLabel(ChatConversation conversation) {
    if (conversation.idAdminSoporte != null) {
      return 'Asistente virtual';
    }
    if (conversation.idPedido != null) {
      final suffix = conversation.activa ? '' : ' (cerrado)';
      return 'Pedido #${conversation.idPedido}$suffix';
    }
    if (!conversation.activa) {
      return 'Conversacion archivada';
    }
    final rawId = conversation.idConversacion.toString();
    final shortId = rawId.length > 4 ? rawId.substring(rawId.length - 4) : rawId;
    return 'Chat #$shortId';
  }

  String _conversationSubtitle(
    ChatConversation conversation, {
    required bool isBot,
    bool includePreview = true,
  }) {
    final ChatMessage? lastMessage =
        conversation.mensajes.isNotEmpty ? conversation.mensajes.last : null;
    final DateTime referenceDate = lastMessage?.fechaEnvio ?? conversation.fechaCreacion;
    final String formattedDate = _dateFormat.format(referenceDate);

    String baseLabel;
    if (conversation.idPedido != null) {
      baseLabel = 'Pedido #${conversation.idPedido}';
      if (!conversation.activa) {
        baseLabel = '$baseLabel cerrado';
      }
    } else if (isBot) {
      baseLabel = 'Asistente disponible';
    } else if (!conversation.activa) {
      baseLabel = 'Conversacion archivada';
    } else {
      baseLabel = 'Conversacion activa';
    }

    if (!includePreview || lastMessage == null) {
      return '$baseLabel - $formattedDate';
    }

    final String preview = lastMessage.mensaje.trim();
    if (preview.isEmpty) {
      return '$baseLabel - $formattedDate';
    }

    final String truncated = preview.length > 48 ? '${preview.substring(0, 48)}...' : preview;
    return '$baseLabel - $formattedDate - $truncated';
  }
}

class _TypingDots extends StatefulWidget {
  final Color brandColor;
  const _TypingDots({required this.brandColor});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _dotOne;
  late final Animation<double> _dotTwo;
  late final Animation<double> _dotThree;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _dotOne = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
    );
    _dotTwo = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
    );
    _dotThree = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy, color: widget.brandColor, size: 18),
            const SizedBox(width: 10),
            Text(
              'El asistente está escribiendo',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 2),
            _buildDot(_dotOne.value, baseOpacity: 0.5),
            const SizedBox(width: 2),
            _buildDot(_dotTwo.value, baseOpacity: 0.5),
            const SizedBox(width: 2),
            _buildDot(_dotThree.value, baseOpacity: 0.5),
          ],
        );
      },
    );
  }

  Widget _buildDot(double t, {double baseOpacity = 0.25}) {
    final opacity = baseOpacity + (t.clamp(0.0, 1.0) * (1.0 - baseOpacity));
    return Opacity(
      opacity: opacity,
      child: CircleAvatar(
        radius: 3,
        backgroundColor: widget.brandColor,
      ),
    );
  }
}
