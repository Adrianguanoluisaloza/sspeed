package com.mycompany.delivery.api.controller;

import com.mycompany.delivery.api.repository.ProductoRepository;
import com.mycompany.delivery.api.repository.RecomendacionRepository;
import com.mycompany.delivery.api.repository.UsuarioRepository;
import com.mycompany.delivery.api.util.ApiException;
import com.mycompany.delivery.api.util.ApiResponse;
import org.postgresql.util.PSQLException;

import java.sql.SQLException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class RecomendacionController {

    private final RecomendacionRepository recomendacionRepository = new RecomendacionRepository();
    private final ProductoRepository productoRepository = new ProductoRepository();
    private final UsuarioRepository usuarioRepository = new UsuarioRepository();

    public ApiResponse<Void> guardarRecomendacion(int idProducto, int idUsuario, int puntuacion, String comentario) {
        if (idProducto <= 0 || idUsuario <= 0 || puntuacion < 1 || puntuacion > 5) {
            throw new ApiException(400, "Datos de recomendacion invalidos");
        }
        try {
            if (productoRepository.obtenerPorId(idProducto).isEmpty()) {
                throw new ApiException(404, "Producto no encontrado");
            }
            if (usuarioRepository.obtenerPorId(idUsuario).isEmpty()) {
                throw new ApiException(404, "Usuario no encontrado");
            }
            boolean ok = recomendacionRepository.guardar(idProducto, idUsuario, puntuacion, comentario);
            if (!ok) {
                throw new ApiException(500, "No se pudo guardar la recomendacion");
            }
            return ApiResponse.created("Recomendacion registrada");
        } catch (SQLException e) {
            if (e instanceof PSQLException psqle) {
                String sqlState = psqle.getSQLState();
                if ("23503".equals(sqlState)) {
                    throw new ApiException(404, mapForeignKeyMessage(psqle), e);
                }
            }
            throw new ApiException(500, "Error guardando recomendacion", e);
        }
    }

    public ApiResponse<Map<String, Object>> obtenerResumenYLista(int idProducto) {
        if (idProducto <= 0) {
            throw new ApiException(400, "Producto invalido");
        }
        try {
            Map<String, Object> resumen = recomendacionRepository.resumen(idProducto);
            List<Map<String, Object>> lista = recomendacionRepository.listarPorProducto(idProducto);
            Map<String, Object> out = new HashMap<>();
            out.put("resumen", resumen);
            out.put("recomendaciones", lista);
            return ApiResponse.success(200, "Recomendaciones del producto", out);
        } catch (SQLException e) {
            throw new ApiException(500, "Error consultando recomendaciones", e);
        }
    }

    private String mapForeignKeyMessage(PSQLException ex) {
        String detail = ex.getServerErrorMessage() != null ? ex.getServerErrorMessage().getDetail() : null;
        if (detail != null) {
            if (detail.contains("(id_producto)")) {
                return "Producto no encontrado";
            }
            if (detail.contains("(id_usuario)")) {
                return "Usuario no encontrado";
            }
        }
        return "Datos de referencia invalidos";
    }
}
