import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_conversation.dart';
import '../models/usuario.dart';
import '../screen/chat_screen.dart';
import '../services/database_service.dart';

class SupportHomeScreen extends StatefulWidget {
  final Usuario supportUser;

  const SupportHomeScreen({super.key, required this.supportUser});

  @override
  State<SupportHomeScreen> createState() => _SupportHomeScreenState();
}

class _SupportHomeScreenState extends State<SupportHomeScreen> {
  late Future<List<ChatConversation>> _conversationsFuture;

  @override
  void initState() {
    super.initState();
    _conversationsFuture = _fetchConversations();
  }

  Future<List<ChatConversation>> _fetchConversations() {
    final database = context.read<DatabaseService>();
    return database.getConversaciones(widget.supportUser.idUsuario);
  }

  Future<void> _handleRefresh() async {
    final updatedFuture = _fetchConversations();
    setState(() {
      _conversationsFuture = updatedFuture;
    });
    await updatedFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de soporte'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesion',
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<DatabaseService>().setAuthToken(null);
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: FutureBuilder<List<ChatConversation>>(
          future: _conversationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 32),
                children: const [
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _SupportInfoMessage(
                    icon: Icons.error_outline,
                    message:
                        'No se pudieron cargar las conversaciones: ${snapshot.error}',
                  ),
                ],
              );
            }

            final conversations = snapshot.data ?? const [];
            if (conversations.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  _SupportInfoMessage(
                    icon: Icons.forum_outlined,
                    message:
                        'No hay conversaciones activas en este momento. Desliza hacia abajo para actualizar.',
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: conversations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                final chips = <String>[];
                if (conversation.idCliente != null) {
                  chips.add('Cliente #${conversation.idCliente}');
                }
                if (conversation.idDelivery != null) {
                  chips.add('Delivery #${conversation.idDelivery}');
                }
                if (conversation.idPedido != null) {
                  chips.add('Pedido #${conversation.idPedido}');
                }

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Theme.of(context).colorScheme.primary.withAlpha(24),
                      child: Icon(
                        Icons.support_agent,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      'Conversacion #${conversation.idConversacion}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: chips.isEmpty
                        ? const Text('Sin detalles adicionales')
                        : Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: chips
                                .map((chip) => Chip(
                                      label: Text(chip),
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withAlpha(18),
                                    ))
                                .toList(),
                          ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            currentUser: widget.supportUser,
                            initialSection: ChatSection.soporte,
                            idConversacion: conversation.idConversacion,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SupportInfoMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _SupportInfoMessage({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: Colors.grey.shade600),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
