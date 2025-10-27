package com.mycompany.delivery.api.controller;

import com.mycompany.delivery.api.UbicacionService;
import com.mycompany.delivery.api.model.Ubicacion;
import com.mycompany.delivery.api.util.ApiException;
import com.mycompany.delivery.api.util.ApiResponse;
import java.sql.SQLException;
import java.util.List;

public class UbicacionController {

    private final UbicacionService service = new UbicacionService();

    // ===============================
    // CREAR O ACTUALIZAR UBICACIÓN
    // ===============================
    public ApiResponse<Ubicacion> guardarUbicacion(Ubicacion ubicacion) {
        var saved = service.guardarUbicacion(ubicacion)
                .orElseThrow(() -> new ApiException(500, "No se pudo guardar la ubicación"));
        return ApiResponse.success(201, "Ubicación guardada correctamente", saved);
    }

    // ===============================
    // ACTUALIZAR COORDENADAS (EN VIVO)
    // ===============================
    public ApiResponse<Void> actualizarUbicacionRepartidor(int idRepartidor, double latitud, double longitud) {
        try {
            var req = new com.mycompany.delivery.api.config.UbicacionUpdateRequest();
            req.setLatitud(latitud);
            req.setLongitud(longitud);
            service.actualizarUbicacionRepartidor(idRepartidor, req);
            return ApiResponse.success("Ubicación actualizada correctamente");
        } catch (ApiException e) {
            throw e;
        } catch (Exception e) {
            throw new ApiException(500, "Error al actualizar la ubicación", e);
        }
    }

    // ===============================
    // ACTUALIZAR COORDENADAS (para DeliveryApi)
    // ===============================
    public void actualizarCoordenadas(int idUsuario, Double latitud, Double longitud) {
        if (idUsuario <= 0 || latitud == null || longitud == null) {
            throw new ApiException(400, "Datos de coordenadas inválidos");
        }

        try {
            var req = new com.mycompany.delivery.api.config.UbicacionUpdateRequest();
            req.setLatitud(latitud);
            req.setLongitud(longitud);
            service.actualizarUbicacionRepartidor(idUsuario, req);
        } catch (Exception e) {
            throw new ApiException(500, "Error inesperado al actualizar coordenadas", e);
        }
    }

    // ===============================
    // OBTENER UBICACIONES POR USUARIO
    // ===============================
    public ApiResponse<List<Ubicacion>> obtenerUbicacionesPorUsuario(int idUsuario) {
        if (idUsuario <= 0)
            throw new ApiException(400, "ID de usuario inválido");

        try {
            List<Ubicacion> ubicaciones = service.obtenerUbicacionesPorUsuario(idUsuario);
            return ApiResponse.success(200, "Ubicaciones obtenidas correctamente", ubicaciones);
        } catch (SQLException e) {
            throw new ApiException(500, "Error al obtener ubicaciones del usuario", e);
        }
    }

    // ===============================
    // LISTAR TODAS LAS UBICACIONES ACTIVAS
    // ===============================
    public ApiResponse<List<Ubicacion>> listarActivas() {
        try {
            List<Ubicacion> activas = service.listarUbicacionesActivas();
            return ApiResponse.success(200, "Ubicaciones activas obtenidas", activas);
        } catch (SQLException e) {
            throw new ApiException(500, "Error al listar ubicaciones activas", e);
        }
    }

    // ===============================
    // ELIMINAR UBICACIÓN
    // ===============================
    public ApiResponse<Void> eliminarUbicacion(int idUbicacion) {
        if (idUbicacion <= 0)
            throw new ApiException(400, "ID de ubicación inválido");
        try {
            boolean ok = service.eliminarUbicacion(idUbicacion);
            if (!ok) throw new ApiException(404, "Ubicación no encontrada");
            return ApiResponse.success("Ubicación eliminada correctamente");
        } catch (SQLException e) {
            throw new ApiException(500, "Error al eliminar la ubicación", e);
        }
    }
}
