/// Mensaje individual intercambiado dentro de una conversaciÃ³n.
class ChatMessage {
  final int idMensaje;
  final int idConversacion;
  final int idRemitente;
  final String mensaje;
  final DateTime? fechaEnvio;
  final String? remitenteNombre;
  final bool esBot;

  const ChatMessage({
    required this.idMensaje,
    required this.idConversacion,
    required this.idRemitente,
    required this.mensaje,
    this.fechaEnvio,
    this.remitenteNombre,
    this.esBot = false,
  });

  // CORRECCIÃ“N: Se aÃ±ade el factory constructor para el indicador de "escribiendo..."
  factory ChatMessage.typing() {
    return ChatMessage(
      idMensaje: -1, // ID especial para identificar este estado en la UI
      idConversacion: 0,
      idRemitente: 0,
      mensaje: '...',
      fechaEnvio: DateTime.now(),
    );
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    int parseInt(dynamic value) {
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    String? readString(List<String> keys) {
      for (final key in keys) {
        final raw = map[key];
        if (raw == null) continue;
        return raw.toString();
      }
      return null;
    }

    return ChatMessage(
      idMensaje: parseInt(map['id_mensaje'] ?? map['idMensaje'] ?? map['id'] ?? 0),
      idConversacion:
          parseInt(map['id_conversacion'] ?? map['idConversacion'] ?? 0),
      idRemitente: parseInt(map['id_remitente'] ?? map['idRemitente'] ?? 0),
      mensaje: readString(['mensaje', 'message']) ?? 'Sin datos',
      fechaEnvio: parseDate(map['fecha_envio'] ?? map['sentAt']),
      remitenteNombre: readString(['remitente_nombre', 'senderName']),
      esBot: (map['es_bot'] ?? map['esBot']) == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_mensaje': idMensaje,
      'id_conversacion': idConversacion,
      'id_remitente': idRemitente,
      'mensaje': mensaje,
      'fecha_envio': fechaEnvio?.toIso8601String(),
      'remitente_nombre': remitenteNombre,
      'es_bot': esBot,
    }..removeWhere((key, value) => value == null);
  }
}
