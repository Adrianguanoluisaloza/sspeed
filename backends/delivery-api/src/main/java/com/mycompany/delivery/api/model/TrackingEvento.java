package com.mycompany.delivery.api.model;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.Map;

public class TrackingEvento {

    private int idPedido;
    private int orden;
    private double latitud;
    private double longitud;
    private String descripcion;
    private OffsetDateTime fechaEvento;

    public int getIdPedido() {
        return idPedido;
    }

    public void setIdPedido(int idPedido) {
        this.idPedido = idPedido;
    }

    public int getOrden() {
        return orden;
    }

    public void setOrden(int orden) {
        this.orden = orden;
    }

    public double getLatitud() {
        return latitud;
    }

    public void setLatitud(double latitud) {
        this.latitud = latitud;
    }

    public double getLongitud() {
        return longitud;
    }

    public void setLongitud(double longitud) {
        this.longitud = longitud;
    }

    public String getDescripcion() {
        return descripcion;
    }

    public void setDescripcion(String descripcion) {
        this.descripcion = descripcion;
    }

    public OffsetDateTime getFechaEvento() {
        return fechaEvento;
    }

    public void setFechaEvento(OffsetDateTime fechaEvento) {
        this.fechaEvento = fechaEvento;
    }

    public Map<String, Object> toMap() {
        Map<String, Object> map = new HashMap<>();
        map.put("id_pedido", idPedido);
        map.put("orden", orden);
        map.put("latitud", latitud);
        map.put("longitud", longitud);
        if (descripcion != null && !descripcion.isBlank()) {
            map.put("descripcion", descripcion);
        }
        if (fechaEvento != null) {
            map.put("fecha_evento", fechaEvento.toString());
        }
        return map;
    }

    public void setFechaEvento(java.sql.Timestamp timestamp) {
        if (timestamp != null) {
            this.fechaEvento = timestamp.toInstant().atOffset(ZoneOffset.UTC);
        }
    }
}
