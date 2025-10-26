package com.mycompany.delivery.api.config;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import java.sql.Connection;
import java.sql.SQLException;

/**
 * Gestiona el pool HikariCP reutilizado por toda la API.
 * Centralizar aquí la reconexión evita fugas de conexiones y mejora la estabilidad.
 */
public final class Database {

    private static final Object LOCK = new Object();
    private static HikariDataSource dataSource;

    static {
        initialiseDataSource();
    }

    private Database() {
    }

    private static void initialiseDataSource() {
        HikariConfig config = new HikariConfig();
        // Permitimos sobreescribir la configuración vía variables de entorno para despliegues seguros.
        config.setJdbcUrl(getEnv("DB_URL", "jdbc:postgresql://ep-quiet-thunder-ady30ys2-pooler.c-2.us-east-1.aws.neon.tech:5432/neondb?sslmode=require"));
        config.setUsername(getEnv("DB_USER", "neondb_owner"));
        config.setPassword(getEnv("DB_PASSWORD", "npg_2YaqWcHBVzO6"));
        config.addDataSourceProperty("maximumPoolSize", getEnv("DB_POOL_SIZE", "10"));
        config.addDataSourceProperty("cachePrepStmts", "true");
        config.addDataSourceProperty("prepStmtCacheSize", "250");
        config.addDataSourceProperty("prepStmtCacheSqlLimit", "2048");

        if (dataSource != null) {
            dataSource.close();
        }

        dataSource = new HikariDataSource(config);
        System.out.println("✅ Pool de conexiones inicializado/reiniciado correctamente.");
    }

    private static String getEnv(String key, String fallback) {
        String value = System.getenv(key);
        return value == null || value.isBlank() ? fallback : value;
    }

    private static void ensureDataSource() {
        synchronized (LOCK) {
            if (dataSource == null || dataSource.isClosed()) {
                // Intentamos reconstruir el pool si se cerró o falló.
                initialiseDataSource();
            }
        }
    }

    /**
     * Obtiene una conexión válida del pool.
     */
    public static Connection getConnection() throws SQLException {
        ensureDataSource();
        return dataSource.getConnection();
    }

    /**
     * Verifica el estado de la conexión para detectar fallos tempranamente.
     */
    public static void ping() {
        try (Connection connection = getConnection()) {
            if (!connection.isValid(5)) {
                throw new SQLException("Conexión devuelta por el pool no es válida");
            }
        } catch (SQLException e) {
            System.err.println("❌ Fallo al verificar la base de datos: " + e.getMessage());
            throw new RuntimeException("No se pudo establecer conexión estable con PostgreSQL", e);
        }
    }
}
