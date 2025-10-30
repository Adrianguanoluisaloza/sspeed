import 'chat_message.dart';

// CORRECCIÓN INTEGRAL DEL MODELO
class ChatConversation {
  final int idConversacion;
  final int? idCliente;
  final int? idDelivery;
  final int? idAdminSoporte;
  final int? idPedido;
  final DateTime fechaCreacion;
  final bool esChatbot;
  final bool activa;
  final List<ChatMessage> mensajes;

  const ChatConversation({
    required this.idConversacion,
    required this.fechaCreacion,
    this.activa = true,
    this.idCliente,
    this.idDelivery,
    this.idAdminSoporte,
    this.idPedido,
    this.esChatbot = false,
    this.mensajes = const [],
  });

  factory ChatConversation.fromMap(Map<String, dynamic> map) {
    dynamic readValue(List<String> keys) {
      for (final key in keys) {
        if (map.containsKey(key) && map[key] != null) return map[key];
      }
      return null;
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    final messagesRaw = readValue(['mensajes', 'messages']) as List?;
    final messageList = messagesRaw
            ?.map((item) =>
                ChatMessage.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList() ??
        [];

    return ChatConversation(
      idConversacion:
          parseInt(readValue(['id_conversacion', 'idConversacion', 'id'])) ?? 0,
      idCliente: parseInt(readValue(['id_cliente', 'idCliente'])),
      idDelivery: parseInt(readValue(['id_delivery', 'idDelivery'])),
      idAdminSoporte:
          parseInt(readValue(['id_admin_soporte', 'idAdminSoporte'])),
      idPedido: parseInt(readValue(['id_pedido', 'idPedido'])),
      fechaCreacion: parseDate(
          readValue(['fecha_creacion', 'fechaCreacion', 'createdAt'])),
      esChatbot: readValue(['es_chatbot', 'esChatbot']) as bool? ?? false,
      activa: readValue(['activa', 'isActive']) as bool? ?? true,
      mensajes: messageList,
    );
  }

  // copyWith para facilitar la actualización de mensajes
  ChatConversation copyWith({List<ChatMessage>? mensajes}) {
    return ChatConversation(
      idConversacion: idConversacion,
      fechaCreacion: fechaCreacion,
      activa: activa,
      idCliente: idCliente,
      idDelivery: idDelivery,
      idAdminSoporte: idAdminSoporte,
      idPedido: idPedido,
      esChatbot: esChatbot,
      mensajes: mensajes ?? this.mensajes,
    );
  }

  // Método para determinar el título del chat
  String get aDisplayTitle {
    if (esChatbot) {
      return 'CIA Bot';
    }
    if (idAdminSoporte != null) {
      return 'Soporte y Ayuda';
    }
    if (idPedido != null) {
      return 'Pedido #$idPedido';
    }
    if (idDelivery != null) {
      return 'Chat con Repartidor';
    }
    if (idCliente != null) {
      return 'Chat con Cliente';
    }
    return 'Conversacion #';
  }
}
