import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/usuario.dart';
import 'package:flutter_application_2/screen/chat_screen.dart';
import 'package:flutter_application_2/screen/profile_screen.dart';
import 'home_screen.dart';

class MainNavigator extends StatefulWidget {
  final Usuario usuario;
  const MainNavigator({super.key, required this.usuario});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0;
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      HomeScreen(usuario: widget.usuario),
      ChatScreen(initialSection: ChatSection.soporte),
      ProfileScreen(usuario: widget.usuario),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      // SE APLICA EL REDISEÑO VISUAL A LA BARRA DE NAVEGACIÓN
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, -5), // Sombra hacia arriba
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.support_agent_outlined),
              activeIcon: Icon(Icons.support_agent),
              label: 'Soporte',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          
          // --- Mejoras Visuales ---
          backgroundColor: Colors.transparent, // Fondo transparente para ver el container
          elevation: 0, // Eliminamos la sombra por defecto, usamos la nuestra
          type: BottomNavigationBarType.fixed, // Mantiene el layout estable
          selectedItemColor: theme.colorScheme.primary, // Color del tema para el ítem activo
          unselectedItemColor: Colors.grey.shade600, // Color neutro para ítems inactivos
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          showUnselectedLabels: true,
        ),
      ),
    );
  }
}
