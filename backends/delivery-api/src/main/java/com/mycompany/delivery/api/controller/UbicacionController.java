package com.mycompany.delivery.api.controller;

import java.sql.SQLException;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import com.mycompany.delivery.api.model.TrackingEvento;
import com.mycompany.delivery.api.model.Ubicacion;
import com.mycompany.delivery.api.services.UbicacionService;
import com.mycompany.delivery.api.util.ApiException;
import com.mycompany.delivery.api.util.ApiResponse;

public class UbicacionController {

    private final UbicacionService service = new UbicacionService();

    private final com.mycompany.delivery.api.services.GoogleMapsService mapsService = new com.mycompany.delivery.api.services.GoogleMapsService();

    // ===============================
    // CREAR O ACTUALIZAR UBICACIÓN
    // ===============================
    public ApiResponse<Map<String, Object>> guardarUbicacion(Ubicacion ubicacion) {
        var saved = service.guardarUbicacion(ubicacion)
                .orElseThrow(() -> new ApiException(500, "No se pudo guardar la ubicación"));
        return ApiResponse.success(201, "Ubicación guardada correctamente", saved.toMap());
    }

    // ===============================
    // GEOCODIFICAR DIRECCIÓN (Google Maps)
    // ===============================
    public ApiResponse<String> geocodificarDireccion(String direccion) {
        if (direccion == null || direccion.isBlank()) {
            throw new ApiException(400, "La dirección es obligatoria");
        }
        String resultado = mapsService.geocodeAddress(direccion);
        if (resultado == null) {
            throw new ApiException(500, "No se pudo obtener la geocodificación de Google Maps");
        }
        return ApiResponse.success(200, "Geocodificación exitosa", resultado);
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
            if (!ok)
                throw new ApiException(404, "Ubicación no encontrada");
            return ApiResponse.success("Ubicación eliminada correctamente");
        } catch (SQLException e) {
            throw new ApiException(500, "Error al eliminar la ubicación", e);
        }
    }

    public ApiResponse<Map<String, Object>> obtenerUbicacionTracking(int idPedido) {
        try {
            java.util.Optional<Map<String, Double>> optUbicacion = service.obtenerUbicacionTracking(idPedido);
            Map<String, Double> ubicacion = optUbicacion.isPresent() ? optUbicacion.get() : null;
            if (ubicacion == null || ubicacion.isEmpty()) {
                throw new ApiException(404, "No se encontró la ubicación de seguimiento para este pedido.");
            }
            java.util.Map<String, Object> out = new java.util.HashMap<>();
            out.put("latitud", ubicacion.get("latitud"));
            out.put("longitud", ubicacion.get("longitud"));
            return ApiResponse.success(200, "Ubicacion en vivo", out);
        } catch (SQLException e) {
            throw new ApiException(500, "Error al obtener tracking", e);
        }
    }

    public ApiResponse<List<Map<String, Object>>> obtenerRutaTracking(int idPedido) {
        try {
            var eventos = service.obtenerRutaPedido(idPedido);
            var payload = eventos.stream().map(TrackingEvento::toMap).collect(Collectors.toList());
            if (payload.isEmpty()) {
                throw new ApiException(404, "No hay puntos de ruta registrados para este pedido.");
            }
            return ApiResponse.success(200, "Ruta de seguimiento", payload);
        } catch (SQLException e) {
            throw new ApiException(500, "Error al obtener la ruta de tracking", e);
        }
    }

    /**
     * Obtiene las últimas ubicaciones de una lista de repartidores.
     *
     * @param repartidorIds La lista de IDs de los repartidores.
     * @return Una respuesta de API con una lista de mapas, donde cada mapa contiene
     *         el id del repartidor y sus coordenadas.
     */
    public ApiResponse<List<Map<String, Object>>> obtenerUbicacionesDeRepartidores(List<Integer> repartidorIds) {
        if (repartidorIds == null || repartidorIds.isEmpty()) {
            throw new ApiException(400, "La lista de IDs de repartidores no puede estar vacía.");
        }
        return ApiResponse.success(200, "Ubicaciones obtenidas",
                service.obtenerUbicacionesDeRepartidores(repartidorIds));
    }
}
