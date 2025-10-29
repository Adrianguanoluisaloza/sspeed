import 'package:flutter/material.dart';

/// Clase centralizada para gestionar el tema visual de la aplicación.
///
/// Define colores, tipografías y estilos de widgets de forma consistente
/// en toda la app.
class AppTheme {
  // Hacemos el constructor privado para que no se pueda instanciar la clase.
  AppTheme._();

  // --- PALETA DE COLORES PRINCIPAL ---
  static const Color primaryColor = Color(0xFFF97316); // Naranja Vibrante
  static const Color accentColor = Color(0xFF1E3A8A);  // Azul Oscuro
  static const Color backgroundColor = Color(0xFFF0F2F5); // Un gris muy claro

  /// Devuelve el ThemeData principal de la aplicación.
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',

      // --- ESQUEMA DE COLORES GLOBAL ---
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: accentColor,
        surface: backgroundColor,
        background: backgroundColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.black87,
        error: Colors.red.shade700,
        onError: Colors.white,
      ),

      // --- COLORES DE LA UI ---
      scaffoldBackgroundColor: backgroundColor,

      // --- ESTILOS DE WIDGETS PRINCIPALES ---

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black26,
        titleTextStyle: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),

      // Botones Elevados
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          textStyle: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),

      // Tarjetas
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      ),

      // Campos de Texto
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        prefixIconColor: primaryColor.withAlpha(179),
        labelStyle: TextStyle(color: accentColor),
        hintStyle: TextStyle(color: Colors.grey.shade500),
      ),

      // Chips (filtros de categorías)
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: primaryColor,
        secondarySelectedColor: primaryColor,
        labelStyle: const TextStyle(color: Colors.black87),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: Colors.black12),
      ),
    );
  }
}
