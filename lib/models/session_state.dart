import 'package:flutter/foundation.dart';

import 'usuario.dart';

/// Controlador sencillo para manejar el estado de sesión dentro de la app.
class SessionController extends ChangeNotifier {
  // CORRECCIÓN: El estado inicial es un usuario no autenticado.
  Usuario _usuario = Usuario.noAuth();

  Usuario get usuario => _usuario;

  // CORRECCIÓN: La lógica de autenticación ahora depende del modelo Usuario.
  bool get isAuthenticated => _usuario.isAuthenticated;

  /// Cierra la sesión del usuario actual.
  void clearUser() {
    _usuario = Usuario.noAuth();
    notifyListeners();
  }

  /// Establece un nuevo usuario como sesión activa.
  void setUser(Usuario usuario) {
    _usuario = usuario;
    notifyListeners();
  }
}
