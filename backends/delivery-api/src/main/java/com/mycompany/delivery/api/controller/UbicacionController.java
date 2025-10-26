package com.mycompany.delivery.api.controller;

import com.mycompany.delivery.api.model.Ubicacion;
// Se resuelve el conflicto importando UbicacionRepository, que es la clase correcta y limpia.
import com.mycompany.delivery.api.repository.UbicacionRepository; 
import com.mycompany.delivery.api.util.ApiException;
import com.mycompany.delivery.api.util.ApiResponse;
import java.sql.SQLException;
import java.util.List;
import java.util.Optional;

/**
 * Controlador de ubicaciones con respuestas JSON uniformes para Flutter.
 */
public class UbicacionController {

    // Se usa UbicacionRepository en lugar del DAO corrupto.
    private final UbicacionRepository repo = new UbicacionRepository();

    public ApiResponse<Ubicacion> guardarUbicacion(Ubicacion ubicacion) {
        try {
            if (ubicacion == null) {
                throw new ApiException(400, "El cuerpo de la solicitud es obligatorio");
            }

            // Esta es la lógica correcta que usa el Repositorio
            if (ubicacion.getIdUbicacion() > 0) {
                boolean actualizada = repo.guardarUbicacion(ubicacion);
                if (!actualizada) {
                    throw new ApiException(404, "Ubicación no encontrada para actualizar");
                }
                System.out.println("ℹ️ Ubicación actualizada para usuario: " + ubicacion.getIdUsuario());
                return ApiResponse.success("Ubicación actualizada correctamente", ubicacion);
            }

            Optional<Ubicacion> creada = repo.save(ubicacion);
            if (creada.isEmpty()) {
                throw new ApiException(500, "No se pudo guardar la ubicación");
            }
            System.out.println("ℹ️ Ubicación creada para usuario: " + ubicacion.getIdUsuario());
            return ApiResponse.success(201, "Ubicación guardada correctamente", creada.get());
        } catch (IllegalArgumentException e) {
            throw new ApiException(400, e.getMessage());
        } catch (SQLException e) {
            System.err.println("❌ Error guardando ubicación: " + e.getMessage());
            throw new ApiException(500, "Error al guardar la ubicación", e);
        }
    }

    public ApiResponse<Ubicacion> getUbicacion(int idUsuario) {
        if (idUsuario <= 0) {
            throw new ApiException(400, "Identificador de usuario inválido");
        }
        try {
            Optional<Ubicacion> ubicacion = repo.obtenerUbicacion(idUsuario);
            if (ubicacion.isEmpty()) {
                throw new ApiException(404, "No se encontró ubicación para el usuario");
            }
            return ApiResponse.success("Ubicación obtenida", ubicacion.get());
        } catch (SQLException e) {
            System.err.println("❌ Error obteniendo ubicación: " + e.getMessage());
            throw new ApiException(500, "No se pudo obtener la ubicación", e);
        }
    }

    public ApiResponse<List<Ubicacion>> getUbicacionesActivas() {
        try {
            List<Ubicacion> ubicaciones = repo.listarUbicacionesActivas();
            return ApiResponse.success(200, "Ubicaciones activas", ubicaciones);
        } catch (SQLException e) {
            System.err.println("❌ Error listando ubicaciones: " + e.getMessage());
            throw new ApiException(500, "No se pudieron obtener las ubicaciones", e);
        }
    }

    public ApiResponse<Void> eliminarUbicacion(int idUbicacion) {
        if (idUbicacion <= 0) {
            throw new ApiException(400, "Identificador de ubicación inválido");
        }
        try {
            boolean eliminada = repo.eliminarUbicacion(idUbicacion);
            if (!eliminada) {
                throw new ApiException(404, "Ubicación no encontrada para eliminar");
            }
            System.out.println("ℹ️ Ubicación eliminada: " + idUbicacion);
            return ApiResponse.success("Ubicación eliminada correctamente");
        } catch (SQLException e) {
            System.err.println("❌ Error eliminando ubicación: " + e.getMessage());
            throw new ApiException(500, "No se pudo eliminar la ubicación", e);
        }
    }
    
    // Se eliminó todo el código duplicado que el merge había añadido al final del archivo.
}
