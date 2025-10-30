import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

import '../models/ubicacion.dart';
import '../models/usuario.dart';
import '../services/database_service.dart';
import '../models/session_state.dart';
import '../routes/app_routes.dart';
import 'chat_screen.dart';
import 'add_location_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Usuario usuario;
  const ProfileScreen({super.key, required this.usuario});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<List<Ubicacion>>? _ubicacionesFuture;
  int? _defaultLocationId;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _loadDefaultLocation();
  }

  void _loadLocations() {
    setState(() {
      _ubicacionesFuture = Provider.of<DatabaseService>(context, listen: false)
          .getUbicaciones(widget.usuario.idUsuario);
    });
  }

  Future<void> _loadDefaultLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'default_location_${widget.usuario.idUsuario}';
    setState(() {
      _defaultLocationId = prefs.getInt(key);
    });
  }

  Future<void> _setDefaultLocation(int idUbicacion) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'default_location_${widget.usuario.idUsuario}';
    await prefs.setInt(key, idUbicacion);
    if (!mounted) return;
    setState(() {
      _defaultLocationId = idUbicacion;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Ubicacion marcada como predeterminada'),
          backgroundColor: Colors.green),
    );
  }

  Future<void> _goToAddLocation() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddLocationScreen()),
    );
    if (result == true && mounted) {
      _loadLocations();
    }
  }

  Future<void> _handleLogout() async {
    final sessionController = context.read<SessionController>();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    sessionController.clearUser();
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  Future<void> _deleteLocation(int id) async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminacion'),
        content: const Text('Estas seguro de eliminar esta ubicacion?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await dbService.deleteUbicacion(id);
        if (!mounted) return;
        if (success) {
          messenger.showSnackBar(const SnackBar(
            content: Text('Ubicacion eliminada'),
            backgroundColor: Colors.green,
          ));
          _loadLocations();
        } else {
          messenger.showSnackBar(const SnackBar(
            content: Text('No se pudo eliminar la ubicacion'),
            backgroundColor: Colors.red,
          ));
        }
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesion',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(theme, widget.usuario),
            const SizedBox(height: 24),
            Text('Gestion de la cuenta',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: Colors.grey[600])),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _buildMenuOption(
                    context,
                    icon: Icons.edit_outlined,
                    color: Colors.blueAccent,
                    title: 'Editar Perfil',
                    subtitle: 'Actualiza tu nombre y correo',
                    onTap: () => Navigator.of(context).pushNamed(
                      AppRoutes.editProfile,
                      arguments: widget.usuario,
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildMenuOption(
                    context,
                    icon: Icons.receipt_long_outlined,
                    color: Colors.orangeAccent,
                    title: 'Historial de pedidos',
                    subtitle: 'Consulta tus compras anteriores',
                    onTap: () => Navigator.of(context).pushNamed(
                      AppRoutes.orderHistory,
                      arguments: widget.usuario,
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildMenuOption(
                    context,
                    icon: Icons.chat_bubble_outline,
                    color: Colors.teal,
                    title: 'Mis Chats',
                    subtitle: 'Revisa tus conversaciones y chats con el bot',
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.chatHome),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Mis ubicaciones',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder<List<Ubicacion>>(
              future: _ubicacionesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _buildErrorState(
                    'Error al cargar',
                    'No pudimos obtener tus ubicaciones.',
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState(
                    'Sin ubicaciones',
                    'Aun no has guardado ninguna direccion.',
                    onRetry: _goToAddLocation,
                  );
                }
                final ubicaciones = snapshot.data!;
                return Column(
                  children: ubicaciones
                      .map((u) => _buildLocationCard(context, u))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: _buildSpeedDial(context),
    );
  }

  Widget _buildLocationCard(BuildContext context, Ubicacion ubicacion) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.primaryColor.withAlpha(26),
          child:
              Icon(Icons.place_outlined, color: theme.primaryColor, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                ubicacion.descripcion ?? 'Ubicacion guardada',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            if (_defaultLocationId != null &&
                ubicacion.id == _defaultLocationId)
              Row(children: const [
                Icon(Icons.star, color: Colors.amber, size: 18),
                SizedBox(width: 4),
              ]),
          ],
        ),
        subtitle: Text(
          ubicacion.direccion ?? 'Direccion no especificada',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              Navigator.of(context)
                  .push<bool>(
                MaterialPageRoute(
                  builder: (_) => AddLocationScreen(initial: ubicacion),
                ),
              )
                  .then((ok) {
                if (ok == true) _loadLocations();
              });
            } else if (value == 'default' && ubicacion.id != null) {
              _setDefaultLocation(ubicacion.id!);
            } else if (value == 'delete' && ubicacion.id != null) {
              _deleteLocation(ubicacion.id!);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            const PopupMenuItem(
                value: 'default', child: Text('Marcar predeterminada')),
            const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedDial(BuildContext context) {
    return SpeedDial(
      icon: Icons.menu,
      activeIcon: Icons.close,
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      overlayColor: Colors.black,
      overlayOpacity: 0.4,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.add_location_alt_outlined),
          label: 'Anadir ubicacion',
          onTap: _goToAddLocation,
        ),
        SpeedDialChild(
          child: const Icon(Icons.smart_toy),
          label: 'CIA Bot',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  initialSection: ChatSection.ciaBot,
                  currentUser: widget.usuario,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProfileHeader(ThemeData theme, Usuario usuario) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                usuario.nombre.isNotEmpty
                    ? usuario.nombre[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 24,
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 0, width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usuario.nombre,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    usuario.correo,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(30),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildErrorState(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
        child: Column(
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String message,
      {required VoidCallback onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
        child: Column(
          children: [
            const Icon(Icons.map_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Anadir mi primera ubicacion'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

