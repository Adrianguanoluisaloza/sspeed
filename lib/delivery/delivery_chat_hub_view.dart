import 'package:flutter/material.dart';

import '../models/usuario.dart';
import '../screen/chat_screen.dart';

// -------------------------------------------------------------------
// VISTA DE LA PESTAÑA "CHAT"
// -------------------------------------------------------------------

class DeliveryChatHubView extends StatelessWidget {
  final Usuario deliveryUser;
  const DeliveryChatHubView({super.key, required this.deliveryUser});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // CORRECCIÓN: Se elimina `const` de la lista, ya que sus elementos no son constantes de compilación.
    final entries = <_ChatEntry>[
      _ChatEntry(
        section: ChatSection.cliente,
        title: 'Chat con Cliente',
        description: 'Coordina entregas y resuelve dudas con tus clientes.',
        icon: Icons.person_outline,
      ),
      _ChatEntry(
        section: ChatSection.soporte,
        title: 'Chat con Soporte',
        description: 'Conecta con el equipo para reportar incidencias.',
        icon: Icons.support_agent_outlined,
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.primaryColor.withAlpha(25),
              child: Icon(entry.icon, color: theme.primaryColor),
            ),
            title: Text(entry.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(entry.description),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => ChatScreen(
                initialSection: entry.section,
                currentUser: deliveryUser,
              ),
            )),
          ),
        );
      },
    );
  }
}

class _ChatEntry {
  final ChatSection section;
  final String title;
  final String description;
  final IconData icon;

  // CORRECCIÓN: Se elimina `const` del constructor para permitir la creación de la lista en tiempo de ejecución.
  _ChatEntry({
    required this.section,
    required this.title,
    required this.description,
    required this.icon,
  });
}
