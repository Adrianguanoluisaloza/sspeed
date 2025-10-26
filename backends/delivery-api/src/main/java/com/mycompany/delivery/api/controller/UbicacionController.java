package com.mycompany.delivery.api.controller;

import com.mycompany.delivery.api.model.Ubicacion;
import com.mycompany.delivery.api.repository.UbicacionRepository;
import com.mycompany.delivery.api.util.ApiException;
import com.mycompany.delivery.api.util.ApiResponse;
import java.sql.SQLException;
import java.util.List;
import java.util.Optional;

/**
 * Controlador REST para gestionar ubicaciones (CRUD + tracking en vivo).
 */
public class UbicacionController {

    private final UbicacionRepository repo = new UbicacionRepository();

    // ===========================
    // CREAR O ACTUALIZAR
    // ===========================
    public ApiResponse<Ubicacion> guardarUbicacion(Ubicacion ubicacion) {
        try {
            Optional<Ubicacion> saved = repo.guardar(ubicacion);
            if (saved.isEmpty()) {
                throw new ApiException(500, "No se pudo guardar la ubicación");
            }
            return ApiResponse.success(201, "Ubicación guardada correctamente", saved.get());
        } catch (SQLException e) {
            throw new ApiException(500, "Error interno al guardar la ubicación", e);
        }
    }

    // ===========================
    // ACTUALIZAR COORDENADAS
    // ===========================
    public ApiResponse<Void> actualizarCoordenadas(int idUbicacion, double latitud, double longitud) {
        if (idUbicacion <= 0) throw new ApiException(400, "Identificador inválido");
        try {
            boolean ok = repo.actualizarUbicacion(idUbicacion, latitud, longitud);
            if (!ok) throw new ApiException(404, "Ubicación no encontrada para actualizar");
            return ApiResponse.success("Coordenadas actualizadas correctamente");
        } catch (SQLException e) {
            throw new ApiException(500, "Error actualizando coordenadas", e);
        }
    }

    // ===========================
    // OBTENER POR USUARIO
    // ===========================
    public ApiResponse<Ubicacion> obtenerPorUsuario(int idUsuario) {
        if (idUsuario <= 0) throw new ApiException(400, "Identificador de usuario inválido");
        try {
            Optional<Ubicacion> ubicacion = repo.obtenerPorUsuario(idUsuario);
            if (ubicacion.isEmpty()) throw new ApiException(404, "Ubicación no encontrada");
            return ApiResponse.success("Ubicación obtenida", ubicacion.get());
        } catch (SQLException e) {
            throw new ApiException(500, "No se pudo obtener la ubicación", e);
        }
    }

    // ===========================
    // LISTAR TODAS LAS ACTIVAS
    // ===========================
    public ApiResponse<List<Ubicacion>> listarUbicacionesActivas() {
        try {
            List<Ubicacion> ubicaciones = repo.listarActivas();
            return ApiResponse.success(200, "Ubicaciones activas", ubicaciones);
        } catch (SQLException e) {
            throw new ApiException(500, "No se pudieron listar las ubicaciones", e);
        }
    }

    // ===========================
    // ELIMINAR UBICACIÓN
    // ===========================
    public ApiResponse<Void> eliminarUbicacion(int idUbicacion) {
        if (idUbicacion <= 0) throw new ApiException(400, "Identificador inválido");
        try {
            boolean eliminado = repo.eliminar(idUbicacion);
            if (!eliminado) throw new ApiException(404, "Ubicación no encontrada para eliminar");
            return ApiResponse.success("Ubicación eliminada correctamente");
        } catch (SQLException e) {
            throw new ApiException(500, "Error eliminando ubicación", e);
        }
    }
}