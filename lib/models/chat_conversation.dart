import 'chat_message.dart';

/// Representa una conversación del módulo de chat unificado.
///
/// La API Java expone campos en snake_case y camelCase dependiendo de la
/// versión del backend, por lo que normalizamos ambos formatos y dejamos los
/// valores opcionales cuando el rol (cliente, delivery o soporte) no aplica.
class ChatConversation {
  final int idConversacion;
  final int? idCliente;
  final int? idDelivery;
  final int? idAdminSoporte;
  final int? idPedido;
  final String? ultimoMensaje;
  final DateTime? fechaActualizacion;
  final List<ChatMessage> mensajes;

  const ChatConversation({
    required this.idConversacion,
    this.idCliente,
    this.idDelivery,
    this.idAdminSoporte,
    this.idPedido,
    this.ultimoMensaje,
    this.fechaActualizacion,
    this.mensajes = const [],
  });

  factory ChatConversation.fromMap(Map<String, dynamic> map) {
    T? readValue<T>(List<String> keys) {
      for (final key in keys) {
        if (map[key] != null) {
          return map[key] as T?;
        }
      }
      return null;
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final messagesRaw = readValue<List<dynamic>>([
          'mensajes',
          'messages',
        ])
        ?.map((item) =>
            ChatMessage.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    return ChatConversation(
      idConversacion:
          parseInt(readValue(['id_conversacion', 'idConversacion', 'id'])) ?? 0,
      idCliente: parseInt(readValue(['id_cliente', 'idCliente'])),
      idDelivery: parseInt(readValue(['id_delivery', 'idDelivery'])),
      idAdminSoporte:
          parseInt(readValue(['id_admin_soporte', 'idAdminSoporte'])),
      idPedido: parseInt(readValue(['id_pedido', 'idPedido'])),
      ultimoMensaje: readValue(['ultimo_mensaje', 'lastMessage'])?.toString(),
      fechaActualizacion: parseDate(
        readValue(['fecha_actualizacion', 'updatedAt', 'fechaActualizacion']),
      ),
      mensajes: messagesRaw ?? const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_conversacion': idConversacion,
      'id_cliente': idCliente,
      'id_delivery': idDelivery,
      'id_admin_soporte': idAdminSoporte,
      'id_pedido': idPedido,
      'ultimo_mensaje': ultimoMensaje,
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'mensajes': mensajes.map((m) => m.toMap()).toList(),
    }..removeWhere((key, value) => value == null);
  }
}
