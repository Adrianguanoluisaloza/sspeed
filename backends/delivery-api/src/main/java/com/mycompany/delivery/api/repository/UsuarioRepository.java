package com.mycompany.delivery.api.repository;

import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.model.Usuario;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.mindrot.jbcrypt.BCrypt;

/**
 * Repositorio JDBC para usuarios. Mantener consultas preparadas evita inyecciones de SQL.
 */
public class UsuarioRepository {

    public Optional<Usuario> findByCorreo(String correo) throws SQLException {
        String sql = "SELECT id_usuario, nombre, correo, contrasena, rol, telefono, activo FROM usuarios WHERE correo = ?";

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, correo);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(mapUsuario(rs));
                }
            }
        }
        return Optional.empty();
    }

    public boolean crearUsuario(Usuario usuario) throws SQLException {
        String sql = "INSERT INTO usuarios (nombre, correo, contrasena, rol, telefono) VALUES (?, ?, ?, ?, ?)";

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, usuario.getNombre());
            stmt.setString(2, usuario.getCorreo());
            // El hash se genera aquí para garantizar consistencia con otros puntos de la aplicación.
            stmt.setString(3, BCrypt.hashpw(usuario.getContrasena(), BCrypt.gensalt()));
            stmt.setString(4, "cliente");
            stmt.setString(5, usuario.getTelefono());

            return stmt.executeUpdate() > 0;
        }
    }

    /**
     * Actualiza el hash almacenado en base a contraseñas legadas en texto plano.
     * Este método se conserva porque es necesario para la lógica de migración
     * de contraseñas en UsuarioController.
     */
    public boolean actualizarHashContrasena(int idUsuario, String nuevoHash) throws SQLException {
        String sql = "UPDATE usuarios SET contrasena = ? WHERE id_usuario = ?";

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, nuevoHash);
            stmt.setInt(2, idUsuario);
            return stmt.executeUpdate() > 0;
        }
    }

    public List<Usuario> listarUsuarios() throws SQLException {
        String sql = "SELECT id_usuario, nombre, correo, rol, telefono, fecha_registro, activo FROM usuarios ORDER BY fecha_registro DESC";
        List<Usuario> usuarios = new ArrayList<>();

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {

            while (rs.next()) {
                Usuario usuario = new Usuario();
                usuario.setIdUsuario(rs.getInt("id_usuario"));
                usuario.setNombre(rs.getString("nombre"));
                usuario.setCorreo(rs.getString("correo"));
                usuario.setRol(rs.getString("rol"));
                usuario.setTelefono(rs.getString("telefono"));
                usuario.setActivo(rs.getBoolean("activo"));
                usuario.setFechaRegistro(rs.getTimestamp("fecha_registro"));
                usuario.setContrasena(null); // Nunca retornamos hashes por seguridad.
                usuarios.add(usuario);
            }
        }

        return usuarios;
    }

    private Usuario mapUsuario(ResultSet rs) throws SQLException {
        Usuario usuario = new Usuario();
        usuario.setIdUsuario(rs.getInt("id_usuario"));
        usuario.setNombre(rs.getString("nombre"));
        usuario.setCorreo(rs.getString("correo"));
        usuario.setContrasena(rs.getString("contrasena"));
        usuario.setRol(rs.getString("rol"));
        usuario.setTelefono(rs.getString("telefono"));
        usuario.setActivo(rs.getBoolean("activo"));
        return usuario;
    }
}
