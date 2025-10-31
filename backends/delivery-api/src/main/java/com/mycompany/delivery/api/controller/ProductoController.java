package com.mycompany.delivery.api.controller;

import com.mycompany.delivery.api.model.Producto;
import com.mycompany.delivery.api.repository.ProductoRepository;
import com.mycompany.delivery.api.util.ApiException;
import com.mycompany.delivery.api.util.ApiResponse;
import java.sql.SQLException;
import java.util.List;
import java.util.stream.Collectors;
import java.util.Optional;

/**
 * Maneja la lógica de productos y devuelve respuestas consistentes para el
 * frontend.
 */
public class ProductoController {

    private final ProductoRepository repo = new ProductoRepository();

    public ApiResponse<List<Producto>> getAllProductos() {
        try {
            List<Producto> productos = repo.listarTodosLosProductos();
            return ApiResponse.success(200, "Productos recuperados", productos);
        } catch (SQLException e) {
            System.err.println("❌ Error listando productos: " + e.getMessage());
            throw new ApiException(500, "No se pudieron obtener los productos", e);
        }
    }

    public ApiResponse<List<Producto>> buscarProductos(String termino, String categoria) {
        try {
            List<Producto> productos = repo.buscarProductos(termino, categoria);
            return ApiResponse.success(200, "Productos filtrados", productos);
        } catch (SQLException e) {
            System.err.println("❌ Error buscando productos: " + e.getMessage());
            throw new ApiException(500, "No se pudieron buscar los productos", e);
        }
    }

    public ApiResponse<Producto> obtenerProducto(int idProducto) {
        if (idProducto <= 0) {
            throw new ApiException(400, "Identificador de producto invalido");
        }
        try {
            Optional<Producto> producto = repo.obtenerPorId(idProducto);
            if (producto.isEmpty()) {
                throw new ApiException(404, "Producto no encontrado");
            }
            return ApiResponse.success(200, "Producto obtenido", producto.get());
        } catch (SQLException e) {
            System.err.println("? Error obteniendo producto: " + e.getMessage());
            throw new ApiException(500, "Error al obtener el producto", e);
        }
    }

    public ApiResponse<Producto> createProducto(Producto producto) {
        validarProducto(producto);
        try {
            Optional<Producto> creado = repo.crearProducto(producto);
            if (creado.isEmpty()) {
                throw new ApiException(500, "No se pudo crear el producto");
            }
            System.out.println("ℹ️ Producto creado: " + producto.getNombre());
            return ApiResponse.success(201, "Producto creado correctamente", creado.get());
        } catch (SQLException e) {
            System.err.println("❌ Error creando producto: " + e.getMessage());
            throw new ApiException(500, "Error al crear el producto", e);
        }
    }

    public ApiResponse<Producto> updateProducto(int id, Producto producto) {
        if (id <= 0) {
            throw new ApiException(400, "Identificador de producto inválido");
        }
        producto.setIdProducto(id);
        validarProducto(producto);

        try {
            boolean actualizado = repo.actualizarProducto(producto);
            if (!actualizado) {
                throw new ApiException(404, "Producto no encontrado");
            }
            System.out.println("ℹ️ Producto actualizado: " + id);
            return ApiResponse.success("Producto actualizado correctamente", producto);
        } catch (SQLException e) {
            System.err.println("❌ Error actualizando producto: " + e.getMessage());
            throw new ApiException(500, "Error al actualizar el producto", e);
        }
    }

    public ApiResponse<Void> deleteProducto(int idProducto) {
        if (idProducto <= 0) {
            throw new ApiException(400, "Identificador de producto inválido");
        }
        try {
            boolean eliminado = repo.eliminarProducto(idProducto);
            if (!eliminado) {
                throw new ApiException(404, "Producto no encontrado para eliminar");
            }
            System.out.println("ℹ️ Producto marcado como no disponible: " + idProducto);
            return ApiResponse.success("Producto eliminado correctamente");
        } catch (SQLException e) {
            System.err.println("❌ Error eliminando producto: " + e.getMessage());
            throw new ApiException(500, "Error al eliminar el producto", e);
        }
    }

    private void validarProducto(Producto producto) {
        if (producto == null) {
            throw new ApiException(400, "El cuerpo de la solicitud es obligatorio");
        }
        if (producto.getNombre() == null || producto.getNombre().isBlank()) {
            throw new ApiException(400, "El nombre es obligatorio");
        }
        if (producto.getPrecio() <= 0) {
            throw new ApiException(400, "El precio debe ser un valor positivo.");
        }
        if (producto.getCategoria() == null || producto.getCategoria().isBlank()) {
            throw new ApiException(400, "La categoría es obligatoria.");
        }
        if (producto.getDescripcion() == null) {
            producto.setDescripcion("");
        }
    }

    /**
     * Obtiene una lista de todas las categorías de productos únicas.
     *
     * @return Una respuesta de API con la lista de categorías.
     */
    public ApiResponse<List<String>> obtenerCategorias() {
        try {
            List<String> categorias = repo.listarTodosLosProductos().stream().map(Producto::getCategoria).distinct()
                    .sorted().collect(Collectors.toList());
            return ApiResponse.success(200, "Categorías obtenidas", categorias);
        } catch (SQLException e) {
            throw new ApiException(500, "No se pudieron obtener las categorías", e);
        }
    }
}
