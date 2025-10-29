package com.mycompany.delivery.api.model;

import java.sql.Timestamp;
import java.util.HashMap;
import java.util.Map;

/**
 * Modelo que representa una ubicación de usuario o repartidor.
 * Simplificado y compatible con el nuevo sistema de controladores y repositorios.
 */
public class Ubicacion {

    private int idUbicacion;
    private int idUsuario;
    private double latitud;
    private double longitud;
    private String descripcion;
    private String direccion;
    private boolean activa = true;
    private String estado;
    private Timestamp fechaRegistro;

    public Ubicacion() {
    }

    public Ubicacion(int idUbicacion, int idUsuario, double latitud, double longitud, String descripcion, String direccion, boolean activa, String estado) {
        this.idUbicacion = idUbicacion;
        this.idUsuario = idUsuario;
        this.latitud = latitud;
        this.longitud = longitud;
        this.descripcion = descripcion;
        this.direccion = direccion;
        this.activa = activa;
        this.estado = estado;
    }

    public int getIdUbicacion() {
        return idUbicacion;
    }

    public void setIdUbicacion(int idUbicacion) {
        this.idUbicacion = idUbicacion;
    }

    public int getIdUsuario() {
        return idUsuario;
    }

    public void setIdUsuario(int idUsuario) {
        this.idUsuario = idUsuario;
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

    public String getDireccion() {
        return direccion;
    }

    public void setDireccion(String direccion) {
        this.direccion = direccion;
    }

    public boolean isActiva() {
        return activa;
    }

    // 👇 Método adicional para compatibilidad con repositorios
    public Boolean getActiva() {
        return activa;
    }

    public void setActiva(boolean activa) {
        this.activa = activa;
    }

    public String getEstado() {
        return estado;
    }

    public void setEstado(String estado) {
        this.estado = estado;
    }

    public Timestamp getFechaRegistro() {
        return fechaRegistro;
    }

    public void setFechaRegistro(Timestamp fechaRegistro) {
        this.fechaRegistro = fechaRegistro;
    }

    public void actualizarCoordenadas(double nuevaLatitud, double nuevaLongitud) {
        this.latitud = nuevaLatitud;
        this.longitud = nuevaLongitud;
    }

    public void toggleActiva(boolean activa) {
        this.activa = activa;
    }

    public boolean isEmpty() {
        return (this.latitud == 0.0 && this.longitud == 0.0);
    }

    @Override
    public String toString() {
        return "Ubicacion{" +
                "idUbicacion=" + idUbicacion +
                ", idUsuario=" + idUsuario +
                ", latitud=" + latitud +
                ", longitud=" + longitud +
                ", descripcion='" + descripcion + '\'' +
                ", direccion='" + direccion + '\'' +
                ", activa=" + activa +
                ", estado='" + estado + '\'' +
                '}';
    }

        /**
         * Devuelve los datos de la ubicación como un Map.
         */
        public Map<String, Object> toMap() {
            Map<String, Object> map = new HashMap<>();
            map.put("idUbicacion", idUbicacion);
            map.put("idUsuario", idUsuario);
            map.put("latitud", latitud);
            map.put("longitud", longitud);
            map.put("descripcion", descripcion);
            map.put("direccion", direccion);
            map.put("activa", activa);
            map.put("estado", estado);
            map.put("fechaRegistro", fechaRegistro);
            return map;
        }
}
