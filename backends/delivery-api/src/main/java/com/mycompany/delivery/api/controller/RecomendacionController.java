/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.mycompany.delivery.api.controller;


import com.mycompany.delivery.api.repository.RecomendacionRepository;
import com.mycompany.delivery.api.util.ApiException;
import com.mycompany.delivery.api.util.ApiResponse;

import java.sql.SQLException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class RecomendacionController {

    private final RecomendacionRepository repo = new RecomendacionRepository();

    public ApiResponse<Void> guardarRecomendacion(int idProducto, int idUsuario, int puntuacion, String comentario) {
        if (idProducto <= 0 || idUsuario <= 0 || puntuacion < 1 || puntuacion > 5)
            throw new ApiException(400, "Datos de recomendación inválidos");
        try {
            boolean ok = repo.guardar(idProducto, idUsuario, puntuacion, comentario);
            if (!ok) throw new ApiException(500, "No se pudo guardar la recomendación");
            return ApiResponse.success("Recomendación registrada");
        } catch (SQLException e) {
            throw new ApiException(500, "Error guardando recomendación", e);
        }
    }

    public ApiResponse<Map<String, Object>> obtenerResumenYLista(int idProducto) {
        if (idProducto <= 0) throw new ApiException(400, "Producto inválido");
        try {
            Map<String, Object> resumen = repo.resumen(idProducto);
            List<Map<String, Object>> lista = repo.listarPorProducto(idProducto);
            Map<String, Object> out = new HashMap<>();
            out.put("resumen", resumen);
            out.put("recomendaciones", lista);
            return ApiResponse.success(200, "Recomendaciones del producto", out);
        } catch (SQLException e) {
            throw new ApiException(500, "Error consultando recomendaciones", e);
        }
    }
}
