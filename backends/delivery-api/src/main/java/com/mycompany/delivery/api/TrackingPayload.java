package com.mycompany.delivery.api;

/**
 * Clase auxiliar usada para recibir las coordenadas de ubicación en vivo
 * enviadas por la app móvil Flutter desde el repartidor.
 */
public class TrackingPayload {

    Double latitud;
    Double longitud;

    public TrackingPayload() {}

    public TrackingPayload(Double latitud, Double longitud) {
        this.latitud = latitud;
        this.longitud = longitud;
    }

    public Double getLatitud() {
        return latitud;
    }

    public void setLatitud(Double latitud) {
        this.latitud = latitud;
    }

    public Double getLongitud() {
        return longitud;
    }

    public void setLongitud(Double longitud) {
        this.longitud = longitud;
    }

    @Override
    public String toString() {
        return "TrackingPayload{" +
                "latitud=" + latitud +
                ", longitud=" + longitud +
                '}';
    }
}
