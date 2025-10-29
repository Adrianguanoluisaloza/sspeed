import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../screen/chat_screen.dart';
import '../screen/live_map_screen.dart';
import '../screen/profile_screen.dart';
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
      const LiveMapScreen(),
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
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _widgetOptions,
          ),
          if (_selectedIndex == 0)
            Positioned(
              bottom: 32,
              right: 24,
              child: FloatingActionButton(
                heroTag: 'ciaBotBubble',
                backgroundColor: theme.colorScheme.primary,
                child: const Icon(Icons.smart_toy, color: Colors.white),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => FractionallySizedBox(
                      heightFactor: 0.92,
                      child: ChatScreen(
                          currentUser: widget.usuario,
                          initialSection: ChatSection.ciaBot),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      // SE APLICA EL REDISEÑO VISUAL A LA BARRA DE NAVEGACIÓN
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
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
              activeIcon: Icon(Icons.shop),
              label: 'Productos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map),
              label: 'Mapa',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Perfil',
            ),
          ],
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: Colors.grey.shade600,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          showUnselectedLabels: true,
        ),
      ),
    );
  }
}
