package com.mycompany.delivery.api.repository;

import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.model.Producto;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Acceso a datos para productos. Todas las consultas son parametrizadas para evitar SQL injection.
 */
public class ProductoRepository {

    public List<Producto> listarTodosLosProductos() throws SQLException {
        String sql = "SELECT id_producto, nombre, descripcion, precio, imagen_url, disponible FROM productos ORDER BY nombre ASC";
        return ejecutarConsultaProductos(sql);
    }

    public List<Producto> buscarProductos(String termino, String categoria) throws SQLException {
        // Se mantiene la versión COALESCE. Es más robusta porque maneja valores NULL 
        // en la columna 'disponible', tratándolos como 'true'.
        StringBuilder sql = new StringBuilder("SELECT id_producto, nombre, descripcion, precio, imagen_url, disponible FROM productos WHERE COALESCE(disponible, true) = true");
        List<Object> parametros = new ArrayList<>();

        if (termino != null && !termino.isBlank()) {
            sql.append(" AND (LOWER(nombre) LIKE LOWER(?) OR LOWER(descripcion) LIKE LOWER(?))");
            String like = "%" + termino.trim() + "%";
            parametros.add(like);
            parametros.add(like);
        }

        // Si el esquema no tiene columna 'categoria', omitimos el filtro para evitar errores.

        sql.append(" ORDER BY nombre ASC");

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < parametros.size(); i++) {
                stmt.setObject(i + 1, parametros.get(i));
            }

            List<Producto> productos = new ArrayList<>();
            try (ResultSet rs = stmt.executeQuery()) {
                while (rs.next()) {
                    productos.add(mapRow(rs));
                }
            }
            return productos;
        }
    }

    public Optional<Producto> crearProducto(Producto producto) throws SQLException {
        String sql = "INSERT INTO productos (nombre, descripcion, precio, imagen_url, categoria, disponible) VALUES (?, ?, ?, ?, ?, ?)";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {

            stmt.setString(1, producto.getNombre());
            stmt.setString(2, producto.getDescripcion());
            stmt.setDouble(3, producto.getPrecio());
            stmt.setString(4, producto.getImagenUrl());
            stmt.setString(5, producto.getCategoria());
            stmt.setBoolean(6, producto.isDisponible());

            int rows = stmt.executeUpdate();
            if (rows > 0) {
                try (ResultSet keys = stmt.getGeneratedKeys()) {
                    if (keys.next()) {
                        producto.setIdProducto(keys.getInt(1));
                        return Optional.of(producto);
                    }
                }
            }
        }
        return Optional.empty();
    }

    public boolean actualizarProducto(Producto producto) throws SQLException {
        String sql = "UPDATE productos SET nombre=?, descripcion=?, precio=?, imagen_url=?, categoria=?, disponible=? WHERE id_producto=?";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {

            stmt.setString(1, producto.getNombre());
            stmt.setString(2, producto.getDescripcion());
            stmt.setDouble(3, producto.getPrecio());
            stmt.setString(4, producto.getImagenUrl());
            stmt.setString(5, producto.getCategoria());
            stmt.setBoolean(6, producto.isDisponible());
            stmt.setInt(7, producto.getIdProducto());

            return stmt.executeUpdate() > 0;
        }
    }

    public boolean eliminarProducto(int idProducto) throws SQLException {
        String sql = "UPDATE productos SET disponible = false WHERE id_producto = ?";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idProducto);
            return stmt.executeUpdate() > 0;
        }
    }

    public Optional<Producto> obtenerPorId(int idProducto) throws SQLException {
        String sql = "SELECT * FROM productos WHERE id_producto = ?";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idProducto);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(mapRow(rs));
                }
            }
        }
        return Optional.empty();
    }

    private List<Producto> ejecutarConsultaProductos(String sql) throws SQLException {
        List<Producto> productos = new ArrayList<>();
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql);
             ResultSet rs = stmt.executeQuery()) {
            while (rs.next()) {
                productos.add(mapRow(rs));
            }
        }
        return productos;
    }

    private Producto mapRow(ResultSet rs) throws SQLException {
        Producto p = new Producto();
        p.setIdProducto(rs.getInt("id_producto"));
        p.setNombre(rs.getString("nombre"));
        p.setDescripcion(rs.getString("descripcion"));
        p.setPrecio(rs.getDouble("precio"));
        p.setImagenUrl(rs.getString("imagen_url"));
        try { p.setCategoria(rs.getString("categoria")); } catch (SQLException ignored) {}

        Boolean disponible = (Boolean) rs.getObject("disponible");
        // Algunos registros antiguos no tenían la columna marcada, los tratamos como disponibles.
        p.setDisponible(disponible == null || disponible);
        return p;
    }
}
        
