import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';

Future<void> showLoginRequiredDialog(BuildContext context) async {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Inicia sesión para continuar'),
      content: const Text(
        'Esta acción requiere que inicies sesión con tu cuenta para guardar tu progreso.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            Navigator.of(context).pushNamed(AppRoutes.login);
          },
          child: const Text('Ir a iniciar sesión'),
        ),
      ],
    ),
  );
}

