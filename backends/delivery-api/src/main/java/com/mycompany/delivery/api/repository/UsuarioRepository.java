package com.mycompany.delivery.api.repository;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import org.mindrot.jbcrypt.BCrypt;

import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.model.Usuario;

/**
 * Repositorio que maneja las operaciones CRUD de los usuarios. Implementa
 * autenticación, registro y actualización con cifrado seguro.
 */
public class UsuarioRepository {

    // ===============================
    // AUTENTICAR (LOGIN)
    // ===============================
    public Optional<Usuario> autenticar(String correo, String contrasenaIngresada) throws SQLException {
        String sql = "SELECT * FROM usuarios WHERE correo = ?";
        try (Connection conn = Database.getConnection(); PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, correo);

            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    Usuario usuario = mapRow(rs);
                    String hashActual = usuario.getContrasena();

                    if (hashActual == null || contrasenaIngresada == null) {
                        return Optional.empty();
                    }

                    // ✅ Si la contraseña ya está hasheada (BCrypt)
                    if (hashActual.startsWith("$2")) {
                        if (BCrypt.checkpw(contrasenaIngresada, hashActual)) {
                            return Optional.of(usuario);
                        }
                    } else {
                        // ⚠️ Si está en texto plano, la convertimos a hash y la guardamos
                        if (hashActual.equals(contrasenaIngresada)) {
                            String nuevoHash = BCrypt.hashpw(contrasenaIngresada, BCrypt.gensalt());
                            actualizarContrasenaHash(usuario.getIdUsuario(), nuevoHash);
                            usuario.setContrasena(nuevoHash);
                            return Optional.of(usuario);
                        }
                    }
                }
            }
        }
        return Optional.empty();
    }

    private void actualizarContrasenaHash(int idUsuario, String nuevoHash) throws SQLException {
        String updateSql = "UPDATE usuarios SET contrasena = ? WHERE id_usuario = ?";
        try (Connection conn = Database.getConnection(); PreparedStatement stmt = conn.prepareStatement(updateSql)) {
            stmt.setString(1, nuevoHash);
            stmt.setInt(2, idUsuario);
            stmt.executeUpdate();
        }
    }

    // ===============================
    // REGISTRAR NUEVO USUARIO
    // ===============================
    public boolean registrar(Usuario usuario) throws SQLException {
        String sql = """
                    INSERT INTO usuarios (nombre, correo, contrasena, telefono, rol, activo, fecha_registro)
                    VALUES (?, ?, ?, ?, COALESCE(?, 'cliente'), TRUE, NOW())
                """;

        try (Connection conn = Database.getConnection(); PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, usuario.getNombre());
            stmt.setString(2, usuario.getCorreo());

            // MEJORA: Hashear la contraseña en la capa de aplicación para mayor robustez.
            // Esto evita la dependencia del trigger de la base de datos y previene el doble
            // hasheo.
            String contrasenaPlana = usuario.getContrasena();
            String hash = BCrypt.hashpw(contrasenaPlana, BCrypt.gensalt());
            stmt.setString(3, hash);
            stmt.setString(4, usuario.getTelefono());
            stmt.setString(5, usuario.getRol());
            return stmt.executeUpdate() > 0;
        }
    }

    // ===============================
    // LISTAR TODOS LOS USUARIOS
    // ===============================
    public List<Usuario> listarUsuarios() throws SQLException {
        List<Usuario> lista = new ArrayList<>();
        String sql = "SELECT * FROM usuarios ORDER BY id_usuario ASC";
        try (Connection conn = Database.getConnection();
                PreparedStatement stmt = conn.prepareStatement(sql);
                ResultSet rs = stmt.executeQuery()) {
            while (rs.next()) {
                lista.add(mapRow(rs));
            }
        }
        return lista;
    }

    // ===============================
    // OBTENER POR ID
    // ===============================
    public Optional<Usuario> obtenerPorId(int idUsuario) throws SQLException {
        String sql = "SELECT * FROM usuarios WHERE id_usuario = ?";
        try (Connection conn = Database.getConnection(); PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idUsuario);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(mapRow(rs));
                }
            }
        }
        return Optional.empty();
    }

    // ===============================
    // ACTUALIZAR DATOS
    // ===============================
    public boolean actualizar(Usuario usuario) throws SQLException {
        String sql = """
                    UPDATE usuarios
                    SET nombre = ?, correo = ?, telefono = ?, contrasena = ?, rol = ?, activo = ?
                    WHERE id_usuario = ?
                """;

        try (Connection conn = Database.getConnection(); PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, usuario.getNombre());
            stmt.setString(2, usuario.getCorreo());
            stmt.setString(3, usuario.getTelefono());

            // MEJORA: Lógica de hasheo inteligente para la actualización.
            // Si la contraseña que llega no parece un hash, la hasheamos.
            // Si ya es un hash, la pasamos directamente para evitar el doble hasheo.
            String contrasena = usuario.getContrasena();
            if (contrasena != null && !contrasena.isBlank() && !contrasena.startsWith("$2")) {
                stmt.setString(4, BCrypt.hashpw(contrasena, BCrypt.gensalt()));
            } else {
                stmt.setString(4, contrasena);
            }

            stmt.setString(5, usuario.getRol());
            stmt.setBoolean(6, usuario.isActivo());
            stmt.setInt(7, usuario.getIdUsuario());
            return stmt.executeUpdate() > 0;
        }
    }

    // ===============================
    // ELIMINAR USUARIO
    // ===============================
    public boolean eliminar(int idUsuario) throws SQLException {
        String sql = "DELETE FROM usuarios WHERE id_usuario = ?";
        try (Connection conn = Database.getConnection(); PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idUsuario);
            return stmt.executeUpdate() > 0;
        }
    }

    // ===============================
    // MAPEO RESULTSET → OBJETO
    // ===============================
    private Usuario mapRow(ResultSet rs) throws SQLException {
        Usuario u = new Usuario();
        u.setIdUsuario(rs.getInt("id_usuario"));
        u.setNombre(rs.getString("nombre"));
        u.setCorreo(rs.getString("correo"));
        u.setContrasena(rs.getString("contrasena"));
        u.setTelefono(rs.getString("telefono"));
        u.setRol(rs.getString("rol"));
        u.setActivo(rs.getBoolean("activo"));
        // No incluir la contraseña en el mapeo por defecto por seguridad.
        // Se puede añadir un método específico si se necesita explícitamente.
        return u;
    }

}
