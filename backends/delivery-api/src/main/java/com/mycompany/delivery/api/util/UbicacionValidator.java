package com.mycompany.delivery.api.util;

/**
 * Utilidades para validar y normalizar datos de ubicaciones.
 */
public final class UbicacionValidator {

    public static final double MIN_LATITUDE = -90.0;
    public static final double MAX_LATITUDE = 90.0;
    public static final double MIN_LONGITUDE = -180.0;
    public static final double MAX_LONGITUDE = 180.0;

    private UbicacionValidator() {
    }

    public static boolean hasValidCoordinates(Double latitud, Double longitud) {
        return latitud != null && longitud != null
                && latitud >= MIN_LATITUDE && latitud <= MAX_LATITUDE
                && longitud >= MIN_LONGITUDE && longitud <= MAX_LONGITUDE;
    }

    public static void requireValidCoordinates(Double latitud, Double longitud, String mensajeError) {
        if (!hasValidCoordinates(latitud, longitud)) {
            throw new IllegalArgumentException(mensajeError);
        }
    }

    public static String requireNonBlank(String valor, String mensajeError) {
        if (valor == null) {
            throw new IllegalArgumentException(mensajeError);
        }
        String limpio = valor.trim();
        if (limpio.isEmpty()) {
            throw new IllegalArgumentException(mensajeError);
        }
        return limpio;
    }

    public static String normalizeDescripcion(String descripcion) {
        return descripcion == null || descripcion.isBlank() ? "Ubicación" : descripcion.trim();
    }

    public static boolean normalizeActiva(Boolean activa) {
        return activa == null || activa;
    }
}
