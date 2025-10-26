package com.mycompany.delivery.api;

import com.mycompany.delivery.api.config.UbicacionUpdateRequest;
import com.mycompany.delivery.api.model.Ubicacion;
import java.sql.SQLException;
import java.util.Optional;

import static com.mycompany.delivery.api.util.UbicacionValidator.normalizeDescripcion;
import static com.mycompany.delivery.api.util.UbicacionValidator.requireNonBlank;
import static com.mycompany.delivery.api.util.UbicacionValidator.requireValidCoordinates;

public class UbicacionService {

    private final UbicacionDAO ubicacionDAO;

    public UbicacionService() {
        this(new UbicacionDAO());
    }

    public UbicacionService(UbicacionDAO ubicacionDAO) {
        this.ubicacionDAO = ubicacionDAO;
    }

    public Optional<Ubicacion> guardarUbicacion(Ubicacion ubicacion) {
        if (ubicacion == null) {
            throw new IllegalArgumentException("La ubicación no puede ser nula");
        }
        if (ubicacion.getIdUsuario() <= 0) {
            throw new IllegalArgumentException("El idUsuario es obligatorio y debe ser mayor a cero");
        }

        requireValidCoordinates(ubicacion.getLatitud(), ubicacion.getLongitud(), "Las coordenadas proporcionadas son inválidas");
        ubicacion.setDireccion(requireNonBlank(ubicacion.getDireccion(), "La dirección es obligatoria"));
        ubicacion.setDescripcion(normalizeDescripcion(ubicacion.getDescripcion()));

        try {
            return ubicacionDAO.save(ubicacion);
        } catch (SQLException e) {
            throw new RuntimeException("Error al guardar la ubicación", e);
        }
    }

    public void actualizarUbicacionRepartidor(int idRepartidor, UbicacionUpdateRequest ubicacionRequest) {
        if (idRepartidor <= 0) {
            throw new IllegalArgumentException("El identificador del repartidor es inválido");
        }
        if (ubicacionRequest == null) {
            throw new IllegalArgumentException("El cuerpo de la solicitud es obligatorio");
        }

        double latitud = ubicacionRequest.getLatitud();
        double longitud = ubicacionRequest.getLongitud();
        requireValidCoordinates(latitud, longitud, "Las coordenadas proporcionadas son inválidas");

        boolean updated = ubicacionDAO.upsertLiveUbicacion(idRepartidor, latitud, longitud);
        if (!updated) {
            throw new IllegalStateException("No se pudo registrar la ubicación en vivo del repartidor");
        }
    }
}
// Se eliminaron las llaves '}' extra al final del archivo.
