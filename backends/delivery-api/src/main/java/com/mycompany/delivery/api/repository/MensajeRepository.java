package com.mycompany.delivery.api.repository;

import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.model.Mensaje;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

/**
 * Repositorio JDBC para manejar los mensajes asociados a pedidos.
 * Se usa tanto para el chat cliente–delivery como para soporte.
 */
public class MensajeRepository {

    // ===========================
    // INSERTAR MENSAJE
    // ===========================
    public boolean insertarMensaje(Mensaje mensaje) throws SQLException {
        String sql = "INSERT INTO mensajes (id_pedido, id_remitente, mensaje, fecha_envio) VALUES (?, ?, ?, CURRENT_TIMESTAMP)";

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, mensaje.getIdPedido());
            stmt.setInt(2, mensaje.getIdRemitente());
            stmt.setString(3, mensaje.getMensaje());
            return stmt.executeUpdate() > 0;
        }
    }

    // ===========================
    // OBTENER MENSAJES POR PEDIDO
    // ===========================
    public List<Mensaje> obtenerMensajesPorPedido(int idPedido) throws SQLException {
        String sql = "SELECT * FROM mensajes WHERE id_pedido = ? ORDER BY fecha_envio ASC";
        List<Mensaje> mensajes = new ArrayList<>();

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idPedido);

            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    mensajes.add(mapRowToMensaje(rs));
                }
            }
        }
        return mensajes;
    }

    // ===========================
    // MAPEO RESULTSET → MODELO
    // ===========================
    private Mensaje mapRowToMensaje(ResultSet rs) throws SQLException {
        Mensaje m = new Mensaje();
        m.setIdMensaje(rs.getInt("id_mensaje"));
        m.setIdPedido(rs.getInt("id_pedido"));
        m.setIdRemitente(rs.getInt("id_remitente"));
        m.setMensaje(rs.getString("mensaje"));
        m.setFechaEnvio(rs.getTimestamp("fecha_envio"));
        return m;
    }
}
