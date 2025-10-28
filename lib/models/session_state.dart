import 'package:flutter/foundation.dart';

import 'usuario.dart';

/// Controlador sencillo para manejar el estado de sesión dentro de la app.
class SessionController extends ChangeNotifier {
  Usuario? _usuario;

  Usuario? get usuario => _usuario;
  bool get isAuthenticated => _usuario != null && _usuario!.idUsuario > 0;

  void setUser(Usuario usuario) {
    _usuario = usuario;
    notifyListeners();
  }

  // Limpia la sesión
  void clearUser() {
    _usuario = null;
    notifyListeners();
  }
}
