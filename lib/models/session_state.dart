import 'package:flutter/foundation.dart';

import 'usuario.dart';

/// Controlador sencillo para manejar el estado de sesión dentro de la app.
class SessionController extends ChangeNotifier {
  Usuario _usuario = Usuario.guest();

  Usuario get usuario => _usuario;
  bool get isGuest => _usuario.isGuest;
  bool get isAuthenticated => !_usuario.isGuest && _usuario.idUsuario > 0;

  void setGuest() {
    _usuario = Usuario.guest();
    notifyListeners();
  }

  void setUser(Usuario usuario) {
    _usuario = usuario;
    notifyListeners();
  }
}
