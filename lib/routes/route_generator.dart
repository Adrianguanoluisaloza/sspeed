import 'package:flutter/material.dart';

import '../admin/admin_home_screen.dart';
import '../delivery/delivery_home_screen.dart';
import '../models/usuario.dart';
import '../screen/edit_profile_screen.dart';
import '../screen/login_screen.dart';
import '../screen/main_navigator.dart';
import '../screen/order_detail_screen.dart';
import '../screen/order_history_screen.dart';
import '../screen/register_screen.dart';
import '../screen/splash_screen.dart';
import '../screen/tracking_simulation_screen.dart'; // IMPORTAMOS LA NUEVA PANTALLA
import 'app_routes.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _fade(settings, const SplashScreen());
      case AppRoutes.login:
        return _slideUp(settings, const LoginScreen());
      case AppRoutes.register:
        return _slideUp(settings, const RegisterScreen());
      case AppRoutes.mainNavigator:
        final usuario = settings.arguments;
        if (usuario is Usuario) {
          return _fade(settings, MainNavigator(usuario: usuario));
        }
        return _redirectToLogin(settings);
      case AppRoutes.editProfile:
        final usuario = settings.arguments;
        if (usuario is Usuario) {
          return _slideUp(settings, EditProfileScreen(usuario: usuario));
        }
        return _redirectToLogin(settings);

      // --- RUTA NUEVA PARA SIMULACIÓN DE TRACKING ---
      case AppRoutes.trackingSimulation:
        final idPedido = settings.arguments;
        if (idPedido is int) {
          return _fade(settings, TrackingSimulationScreen(idPedido: idPedido));
        }
        return _redirectToLogin(settings);

      case AppRoutes.adminHome:
        final usuario = settings.arguments;
        if (usuario is Usuario) {
          return _fade(settings, AdminHomeScreen(adminUser: usuario));
        }
        return _redirectToLogin(settings);
      case AppRoutes.deliveryHome:
        final usuario = settings.arguments;
        if (usuario is Usuario) {
          return _fade(settings, DeliveryHomeScreen(deliveryUser: usuario));
        }
        return _redirectToLogin(settings);
      case AppRoutes.orderDetail:
        final id = settings.arguments;
        if (id is int) {
          return _slideUp(settings, OrderDetailScreen(idPedido: id));
        }
        return _redirectToLogin(settings);
      case AppRoutes.orderHistory:
        final usuario = settings.arguments;
        if (usuario is Usuario) {
          return _slideUp(settings, OrderHistoryScreen(usuario: usuario));
        }
        return _redirectToLogin(settings);
      default:
        return _redirectToLogin(settings);
    }
  }

  static Route<dynamic> _redirectToLogin(RouteSettings settings) {
    return _fade(settings, const LoginScreen());
  }

  static PageRoute _fade(RouteSettings settings, Widget child) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, animation, __) => FadeTransition(opacity: animation, child: child),
    );
  }

  static PageRoute _slideUp(RouteSettings settings, Widget child) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, animation, __) => child,
      transitionsBuilder: (_, animation, secondaryAnimation, widget) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        final fadeAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(opacity: fadeAnimation, child: widget),
        );
      },
    );
  }
}
