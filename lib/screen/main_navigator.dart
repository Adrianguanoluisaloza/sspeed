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
    // Definimos las pantallas aquí para poder pasar el objeto 'usuario'
    _widgetOptions = <Widget>[
      const HomeScreen(),                                 // 0: Inicio
      ChatScreen(initialSection: ChatSection.soporte), // 1: Chat de Soporte
      ProfileScreen(usuario: widget.usuario),              // 2: Perfil
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.support_agent),
            label: 'Soporte',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.deepOrange,
        onTap: _onItemTapped,
      ),
    );
  }
}

