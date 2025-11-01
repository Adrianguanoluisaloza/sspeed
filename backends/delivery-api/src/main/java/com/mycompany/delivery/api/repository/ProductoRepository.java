package com.mycompany.delivery.api.repository;

import com.mycompany.delivery.api.config.Database;
import com.mycompany.delivery.api.model.Producto;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Acceso a datos para productos. Todas las consultas respetan el esquema actual:
 * productos(id_negocio, id_categoria, ...).
 */
public class ProductoRepository {

    private static final String SELECT_BASE = """
            SELECT  p.id_producto,
                    p.nombre,
                    p.descripcion,
                    p.precio,
                    p.imagen_url,
                    p.disponible,
                    p.id_categoria,
                    p.id_negocio,
                    c.nombre AS categoria_nombre
            FROM productos p
            LEFT JOIN categorias c ON p.id_categoria = c.id_categoria
            """;

    public List<Producto> listarTodosLosProductos() throws SQLException {
        String sql = SELECT_BASE + " ORDER BY p.nombre ASC";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            return executeQuery(stmt);
        }
    }

    public List<Producto> buscarProductos(String termino, String categoria) throws SQLException {
        StringBuilder sql = new StringBuilder(SELECT_BASE)
                .append(" WHERE COALESCE(p.disponible, TRUE) = TRUE");
        List<Object> params = new ArrayList<>();

        if (termino != null && !termino.isBlank()) {
            sql.append(" AND (LOWER(p.nombre) LIKE LOWER(?) OR LOWER(p.descripcion) LIKE LOWER(?))");
            String like = "%" + termino.trim() + "%";
            params.add(like);
            params.add(like);
        }

        if (categoria != null && !categoria.isBlank()) {
            sql.append(" AND LOWER(COALESCE(c.nombre, '')) = LOWER(?)");
            params.add(categoria.trim());
        }

        sql.append(" ORDER BY p.nombre ASC");

        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                stmt.setObject(i + 1, params.get(i));
            }
            return executeQuery(stmt);
        }
    }

    public Optional<Producto> crearProducto(Producto producto) throws SQLException {
        try (Connection conn = Database.getConnection()) {
            int idCategoria = resolveCategoriaId(conn, producto);
            int idNegocio = resolveNegocioId(conn, producto, idCategoria);

            String sql = """
                    INSERT INTO productos (id_negocio, id_categoria, nombre, descripcion, precio, imagen_url, disponible)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    RETURNING id_producto
                    """;
            try (PreparedStatement stmt = conn.prepareStatement(sql)) {
                stmt.setInt(1, idNegocio);
                stmt.setInt(2, idCategoria);
                stmt.setString(3, producto.getNombre());
                stmt.setString(4, producto.getDescripcion());
                stmt.setDouble(5, producto.getPrecio());
                stmt.setString(6, producto.getImagenUrl());
                stmt.setBoolean(7, producto.isDisponible());

                try (ResultSet rs = stmt.executeQuery()) {
                    if (rs.next()) {
                        producto.setIdProducto(rs.getInt("id_producto"));
                        producto.setIdCategoria(idCategoria);
                        producto.setIdNegocio(idNegocio);
                        return Optional.of(producto);
                    }
                }
            }
        }
        return Optional.empty();
    }

    public Optional<Producto> crearProductoParaNegocio(Producto producto, int idNegocio) throws SQLException {
        producto.setIdNegocio(idNegocio);
        return crearProducto(producto);
    }

    public Optional<Producto> crearProductoParaProveedor(Producto producto, String proveedorNombre) throws SQLException {
        try (Connection conn = Database.getConnection()) {
            Optional<Integer> negocioId = findNegocioIdByProveedor(conn, proveedorNombre);
            if (negocioId.isEmpty()) {
                return Optional.empty();
            }
            producto.setIdNegocio(negocioId.get());
        }
        return crearProducto(producto);
    }

    public List<Producto> listarPorNegocio(int idNegocio) throws SQLException {
        String sql = SELECT_BASE + " WHERE p.id_negocio = ? ORDER BY p.nombre ASC";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idNegocio);
            return executeQuery(stmt);
        }
    }

    public List<Producto> listarPorProveedor(String proveedorNombre) throws SQLException {
        try (Connection conn = Database.getConnection()) {
            Optional<Integer> negocioId = findNegocioIdByProveedor(conn, proveedorNombre);
            if (negocioId.isEmpty()) {
                return new ArrayList<>();
            }
            return listarPorNegocio(negocioId.get());
        }
    }

    public boolean actualizarProducto(Producto producto) throws SQLException {
        try (Connection conn = Database.getConnection()) {
            int idCategoria = resolveCategoriaId(conn, producto);
            int idNegocio = resolveNegocioId(conn, producto, idCategoria);

            String sql = """
                    UPDATE productos
                    SET id_negocio = ?, id_categoria = ?, nombre = ?, descripcion = ?, precio = ?, imagen_url = ?, disponible = ?
                    WHERE id_producto = ?
                    """;
            try (PreparedStatement stmt = conn.prepareStatement(sql)) {
                stmt.setInt(1, idNegocio);
                stmt.setInt(2, idCategoria);
                stmt.setString(3, producto.getNombre());
                stmt.setString(4, producto.getDescripcion());
                stmt.setDouble(5, producto.getPrecio());
                stmt.setString(6, producto.getImagenUrl());
                stmt.setBoolean(7, producto.isDisponible());
                stmt.setInt(8, producto.getIdProducto());
                return stmt.executeUpdate() > 0;
            }
        }
    }

    public boolean eliminarProducto(int idProducto) throws SQLException {
        String sql = "UPDATE productos SET disponible = FALSE WHERE id_producto = ?";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idProducto);
            return stmt.executeUpdate() > 0;
        }
    }

    public Optional<Producto> obtenerPorId(int idProducto) throws SQLException {
        String sql = SELECT_BASE + " WHERE p.id_producto = ?";
        try (Connection conn = Database.getConnection();
             PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idProducto);
            List<Producto> productos = executeQuery(stmt);
            return productos.isEmpty() ? Optional.empty() : Optional.of(productos.get(0));
        }
    }

    private List<Producto> executeQuery(PreparedStatement stmt) throws SQLException {
        List<Producto> productos = new ArrayList<>();
        try (ResultSet rs = stmt.executeQuery()) {
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
        p.setDisponible(rs.getBoolean("disponible"));

        int idCategoria = rs.getInt("id_categoria");
        if (!rs.wasNull()) {
            p.setIdCategoria(idCategoria);
        }
        int idNegocio = rs.getInt("id_negocio");
        if (!rs.wasNull()) {
            p.setIdNegocio(idNegocio);
        }
        String categoriaNombre = rs.getString("categoria_nombre");
        p.setCategoria(categoriaNombre != null ? categoriaNombre : "");
        return p;
    }

    private int resolveCategoriaId(Connection conn, Producto producto) throws SQLException {
        if (producto.getIdCategoria() > 0) {
            if (categoriaExiste(conn, producto.getIdCategoria())) {
                return producto.getIdCategoria();
            }
            throw new SQLException("La categoria especificada no existe: " + producto.getIdCategoria());
        }
        String nombreCategoria = producto.getCategoria();
        if (nombreCategoria == null || nombreCategoria.isBlank()) {
            throw new SQLException("Categoria obligatoria para registrar el producto");
        }
        String sql = "SELECT id_categoria FROM categorias WHERE LOWER(nombre) = LOWER(?) LIMIT 1";
        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, nombreCategoria.trim());
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    int id = rs.getInt("id_categoria");
                    producto.setIdCategoria(id);
                    return id;
                }
            }
        }
        throw new SQLException("Categoria no encontrada: " + nombreCategoria);
    }

    private boolean categoriaExiste(Connection conn, int idCategoria) throws SQLException {
        String sql = "SELECT 1 FROM categorias WHERE id_categoria = ?";
        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idCategoria);
            try (ResultSet rs = stmt.executeQuery()) {
                return rs.next();
            }
        }
    }

    private int resolveNegocioId(Connection conn, Producto producto, int idCategoria) throws SQLException {
        if (producto.getIdNegocio() != null && producto.getIdNegocio() > 0) {
            return producto.getIdNegocio();
        }
        String sql = "SELECT id_negocio FROM categorias WHERE id_categoria = ?";
        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setInt(1, idCategoria);
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    int idNegocio = rs.getInt("id_negocio");
                    if (rs.wasNull()) {
                        throw new SQLException("La categoria no tiene un negocio asociado");
                    }
                    producto.setIdNegocio(idNegocio);
                    return idNegocio;
                }
            }
        }
        throw new SQLException("No fue posible determinar el negocio para la categoria " + idCategoria);
    }

    private Optional<Integer> findNegocioIdByProveedor(Connection conn, String proveedorNombre) throws SQLException {
        if (proveedorNombre == null || proveedorNombre.isBlank()) {
            return Optional.empty();
        }
        // Si llega el ID directo en texto
        try {
            int id = Integer.parseInt(proveedorNombre.trim());
            return Optional.of(id);
        } catch (NumberFormatException ignored) {
        }

        String sql = """
                SELECT n.id_negocio
                FROM negocios n
                JOIN usuarios u ON n.id_usuario = u.id_usuario
                WHERE LOWER(u.nombre) = LOWER(?) OR LOWER(n.nombre_comercial) = LOWER(?)
                LIMIT 1
                """;
        try (PreparedStatement stmt = conn.prepareStatement(sql)) {
            stmt.setString(1, proveedorNombre.trim());
            stmt.setString(2, proveedorNombre.trim());
            try (ResultSet rs = stmt.executeQuery()) {
                if (rs.next()) {
                    return Optional.of(rs.getInt("id_negocio"));
                }
            }
        }
        return Optional.empty();
    }
}
