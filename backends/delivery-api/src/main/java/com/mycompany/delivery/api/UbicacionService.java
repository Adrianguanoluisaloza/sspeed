package com.mycompany.delivery.api;

import com.mycompany.delivery.api.config.UbicacionUpdateRequest;
import com.mycompany.delivery.api.model.Ubicacion;
import com.mycompany.delivery.api.repository.UbicacionRepository;
import com.mycompany.delivery.api.util.ApiException;

import java.sql.SQLException;
import java.util.List;
import java.util.Optional;

import static com.mycompany.delivery.api.util.UbicacionValidator.*;

public class UbicacionService {

    private final UbicacionRepository repo;

    public UbicacionService() {
        this.repo = new UbicacionRepository();
    }

    // ===============================
    // GUARDAR O ACTUALIZAR UBICACIÓN
    // ===============================
    public Optional<Ubicacion> guardarUbicacion(Ubicacion ubicacion) {
        if (ubicacion == null) {
            throw new ApiException(400, "La ubicación no puede ser nula");
        }
        if (ubicacion.getIdUsuario() <= 0) {
            throw new ApiException(400, "El idUsuario es obligatorio y debe ser mayor a cero");
        }

        requireValidCoordinates(ubicacion.getLatitud(), ubicacion.getLongitud(), "Las coordenadas proporcionadas son inválidas");
        ubicacion.setDireccion(requireNonBlank(ubicacion.getDireccion(), "La dirección es obligatoria"));
        ubicacion.setDescripcion(normalizeDescripcion(ubicacion.getDescripcion()));

        try {
            return repo.guardar(ubicacion);
        } catch (SQLException e) {
            throw new ApiException(500, "Error al guardar la ubicación", e);
        }
    }

    // ===============================
    // ACTUALIZAR UBICACIÓN EN VIVO (REPARTIDOR)
    // ===============================
    public void actualizarUbicacionRepartidor(int idRepartidor, UbicacionUpdateRequest ubicacionRequest) {
        if (idRepartidor <= 0) {
            throw new ApiException(400, "El identificador del repartidor es inválido");
        }
        if (ubicacionRequest == null) {
            throw new ApiException(400, "El cuerpo de la solicitud es obligatorio");
        }

        double latitud = ubicacionRequest.getLatitud();
        double longitud = ubicacionRequest.getLongitud();

        if (latitud == 0.0 || longitud == 0.0) {
            throw new ApiException(400, "Las coordenadas son obligatorias");
        }

        requireValidCoordinates(latitud, longitud, "Las coordenadas proporcionadas son inválidas");

        try {
            boolean updated = repo.actualizarUbicacionLive(idRepartidor, latitud, longitud);
            if (!updated) {
                throw new ApiException(404, "No se pudo registrar la ubicación en vivo del repartidor");
            }
        } catch (SQLException e) {
            throw new ApiException(500, "Error actualizando ubicación del repartidor", e);
        }
    }

    // ===============================
    // OBTENER UBICACIONES POR USUARIO
    // ===============================
    public List<Ubicacion> obtenerUbicacionesPorUsuario(int idUsuario) throws SQLException {
        if (idUsuario <= 0) {
            throw new ApiException(400, "El ID del usuario es inválido");
        }
        return repo.obtenerPorUsuario(idUsuario);
    }

    // ===============================
    // LISTAR TODAS LAS UBICACIONES ACTIVAS
    // ===============================
    public List<Ubicacion> listarUbicacionesActivas() throws SQLException {
        return repo.listarActivas();
    }

    // ===============================
    // ELIMINAR UBICACIÓN
    // ===============================
    public boolean eliminarUbicacion(int idUbicacion) throws SQLException {
        if (idUbicacion <= 0) {
            throw new ApiException(400, "El ID de la ubicación es inválido");
        }
        return repo.eliminar(idUbicacion);
    }
}
