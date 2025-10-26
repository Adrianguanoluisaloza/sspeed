package com.mycompany.delivery.api.repository;

import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.model.Mensaje;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.List;

/**
 * Repositorio para mensajes entre usuarios del pedido.
 */
public class MensajeRepository {

    public boolean enviarMensaje(Mensaje mensaje) throws SQLException {
        String sql = "INSERT INTO mensajes (id_pedido, id_remitente, mensaje, fecha_envio) VALUES (?, ?, ?, ?)";

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, mensaje.getIdPedido());
            stmt.setInt(2, mensaje.getIdRemitente());
            stmt.setString(3, mensaje.getMensaje());
            stmt.setTimestamp(4, new Timestamp(System.currentTimeMillis()));

            int filas = stmt.executeUpdate();
            return filas > 0;
        }
    }

    public List<Mensaje> listarMensajesPorPedido(int idPedido) throws SQLException {
        List<Mensaje> mensajes = new ArrayList<>();
        String sql = "SELECT id_mensaje, id_pedido, id_remitente, mensaje, fecha_envio FROM mensajes WHERE id_pedido = ? ORDER BY fecha_envio ASC";

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setInt(1, idPedido);
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    Mensaje m = new Mensaje();
                    m.setIdMensaje(rs.getInt("id_mensaje"));
                    m.setIdPedido(rs.getInt("id_pedido"));
                    m.setIdRemitente(rs.getInt("id_remitente"));
                    m.setMensaje(rs.getString("mensaje"));
                    m.setFechaEnvio(rs.getTimestamp("fecha_envio"));
                    mensajes.add(m);
                }
            }
        }

        return mensajes;
    }
}
