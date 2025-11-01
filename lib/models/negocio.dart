class Negocio {
  final int idNegocio;
  final int idUsuario;
  final String nombreComercial;
  final String ruc;
  final String? direccion;
  final String? telefono;
  final String? logoUrl;
  final bool activo;

  const Negocio({
    required this.idNegocio,
    required this.idUsuario,
    required this.nombreComercial,
    required this.ruc,
    this.direccion,
    this.telefono,
    this.logoUrl,
    this.activo = true,
  });

  factory Negocio.fromMap(Map<String, dynamic> map) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final v = value.toLowerCase();
        return v == 'true' || v == '1' || v == 't';
      }
      return true;
    }

    dynamic readValue(List<String> keys) {
      for (final key in keys) {
        if (map.containsKey(key) && map[key] != null) {
          return map[key];
        }
      }
      return null;
    }

    return Negocio(
      idNegocio: parseInt(readValue(['id_negocio', 'idNegocio'])),
      idUsuario: parseInt(readValue(['id_usuario', 'idUsuario'])),
      nombreComercial:
          (readValue(['nombre_comercial', 'nombreComercial']) ?? '').toString(),
      ruc: (readValue(['ruc']) ?? '').toString(),
      direccion: readValue(['direccion'])?.toString(),
      telefono: readValue(['telefono'])?.toString(),
      logoUrl: readValue(['logo_url', 'logoUrl'])?.toString(),
      activo: parseBool(readValue(['activo'])),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_negocio': idNegocio > 0 ? idNegocio : null,
      'id_usuario': idUsuario,
      'nombre_comercial': nombreComercial,
      'ruc': ruc,
      'direccion': direccion,
      'telefono': telefono,
      'logo_url': logoUrl,
      'activo': activo,
    }..removeWhere((key, value) => value == null);
  }

  Negocio copyWith({
    int? idNegocio,
    int? idUsuario,
    String? nombreComercial,
    String? ruc,
    String? direccion,
    String? telefono,
    String? logoUrl,
    bool? activo,
  }) {
    return Negocio(
      idNegocio: idNegocio ?? this.idNegocio,
      idUsuario: idUsuario ?? this.idUsuario,
      nombreComercial: nombreComercial ?? this.nombreComercial,
      ruc: ruc ?? this.ruc,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      logoUrl: logoUrl ?? this.logoUrl,
      activo: activo ?? this.activo,
    );
  }
}
