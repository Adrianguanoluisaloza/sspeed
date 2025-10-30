import 'package:flutter/material.dart';

import '../admin/admin_home_screen.dart';
import '../delivery/delivery_home_screen.dart';
import '../models/usuario.dart';
import '../models/ubicacion.dart';
import '../screen/checkout_address_screen.dart';
import '../screen/edit_profile_screen.dart';
import '../screen/login_screen.dart';
import '../screen/main_navigator.dart';
import '../screen/order_detail_screen.dart';
import '../screen/order_history_screen.dart';
import '../screen/register_screen.dart';
import '../screen/splash_screen.dart';
import '../screen/tracking_simulation_screen.dart';
import '../screen/checkout_screen.dart';
import '../screen/order_success_screen.dart';
import '../support/support_home_screen.dart';
import '../screen/product_detail_screen.dart';
import '../models/producto.dart';
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
        final usuario = settings.arguments as Usuario? ??
            const Usuario(idUsuario: 0, nombre: '', correo: '', rol: 'cliente');
        final role = usuario.rol.trim().toLowerCase();
        switch (role) {
          case 'admin':
          case 'negocio':
            return _fade(settings, AdminHomeScreen(adminUser: usuario));
          case 'delivery':
          case 'repartidor':
            return _fade(settings, DeliveryHomeScreen(deliveryUser: usuario));
          case 'soporte':
            return _fade(settings, SupportHomeScreen(supportUser: usuario));
          default:
            return _fade(settings, MainNavigator(usuario: usuario));
        }
      case AppRoutes.editProfile:
        final usuario = settings.arguments;
        if (usuario is Usuario) {
          return _slideUp(settings, EditProfileScreen(usuario: usuario));
        }
        return _redirectToLogin(settings);
      case AppRoutes.trackingSimulation:
        final idPedido = settings.arguments;
        if (idPedido is int) {
          return _fade(settings, TrackingSimulationScreen(idPedido: idPedido));
        }
        return _redirectToLogin(settings);

      // --- RUTAS DE CHECKOUT AÑADIDAS ---
      case AppRoutes.checkout:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args != null && args['usuario'] is Usuario && args['ubicacion'] is Ubicacion) {
          return _slideUp(settings, CheckoutScreen(usuario: args['usuario'], ubicacion: args['ubicacion']));
        }
        return _redirectToLogin(settings);
      case AppRoutes.orderSuccess:
        final usuario = settings.arguments;
        if (usuario is Usuario) {
          return _fade(settings, OrderSuccessScreen(usuario: usuario));
        }
        return _fade(settings, const OrderSuccessScreen());
      case AppRoutes.checkoutAddress:
        final usuario = settings.arguments;
        if (usuario is Usuario) {
          return _slideUp(settings, CheckoutAddressScreen(usuario: usuario));
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
      case AppRoutes.supportHome:
        final usuario = settings.arguments;
        if (usuario is Usuario) {
          return _fade(settings, SupportHomeScreen(supportUser: usuario));
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
      case AppRoutes.productDetail:
        final args = settings.arguments;
        if (args is Map<String, dynamic> && args['producto'] is Producto && args['usuario'] is Usuario) {
          return _slideUp(settings, ProductDetailScreen(producto: args['producto'] as Producto, usuario: args['usuario'] as Usuario));
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