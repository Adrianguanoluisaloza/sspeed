/*import 'package:postgres/postgres.dart';

class NeonService {
  late PostgreSQLConnection connection;

  Future<void> connect() async {
    connection = PostgreSQLConnection(
      'ep-quiet-thunder-ady30ys2-pooler.c-2.us-east-1.aws.neon.tech',
      5432,
      'neondb',
      username: 'neondb_owner',
      password: 'npg_2YaqWcHBVzO6',
      useSSL: true,
    );

    try {
      await connection.open();
      print('✅ Conectado correctamente a Neon PostgreSQL desde Flutter');
    } catch (e) {
      print('❌ Error al conectar: $e');
    }
  }

  Future<void> testQuery() async {
    try {
      final results = await connection.query('SELECT NOW() AS fecha_actual;');
      print('🕒 Fecha actual en Neon: ${results.first[0]}');
    } catch (e) {
      print('❌ Error ejecutando consulta: $e');
    }
  }

  Future<void> close() async {
    await connection.close();
    print('🔌 Conexión cerrada');
  }
}
*/