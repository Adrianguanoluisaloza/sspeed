/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.mycompany.delivery.api.controller;

import com.mycompany.delivery.api.config.Database;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;

/**
 *
 * @author Adrian
 */
public class RecomendacionController {
    
 /**
     * Guarda una nueva recomendación o actualiza si ya existe una del mismo usuario para el mismo producto.
     * Usa la cláusula ON CONFLICT de PostgreSQL.
     * @param idProducto El ID del producto reseñado.
     * @param idUsuario El ID del usuario que reseña.
     * @param puntuacion La puntuación (1-5).
     * @param comentario El comentario (puede ser nulo o vacío).
     * @return true si se guardó/actualizó correctamente, false en caso de error.
     */
    public boolean guardarRecomendacion(int idProducto, int idUsuario, int puntuacion, String comentario) {
        // SQL con ON CONFLICT para hacer UPSERT (INSERT o UPDATE)
        // Si ya existe una recomendación de ese id_usuario para ese id_producto, actualiza la puntuacion y comentario.
        String sql = """
            INSERT INTO recomendaciones (id_producto, id_usuario, puntuacion, comentario)
            VALUES (?, ?, ?, ?)
            ON CONFLICT (id_usuario, id_producto) 
            DO UPDATE SET 
                puntuacion = EXCLUDED.puntuacion, 
                comentario = EXCLUDED.comentario,
                fecha_recomendacion = CURRENT_TIMESTAMP; 
            """;

        try (Connection conn = Database.getConnection();
             PreparedStatement pstmt = conn.prepareStatement(sql)) {

            pstmt.setInt(1, idProducto);
            pstmt.setInt(2, idUsuario);
            pstmt.setInt(3, puntuacion);
            pstmt.setString(4, comentario);

            int filasAfectadas = pstmt.executeUpdate();
            return filasAfectadas > 0; // Si se insertó o actualizó, devuelve true

        } catch (SQLException e) {
            System.err.println("Error al guardar recomendación: " + e.getMessage());
            e.printStackTrace();
            return false;
        }
    }
}