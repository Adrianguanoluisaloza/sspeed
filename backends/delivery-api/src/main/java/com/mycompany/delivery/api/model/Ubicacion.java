package com.mycompany.delivery.api.model;

public class Ubicacion {

    private int idUbicacion;
    private int idUsuario;
    private double latitud;
    private double longitud;
    private String descripcion;
    private String direccion;
    private boolean activa = true;
    private String estado;

    public Ubicacion() {
    }

    public Ubicacion(int idUbicacion, int idUsuario, double latitud, double longitud, String descripcion, String direccion, boolean activa, String estado) {
        // Constructor completo para evitar errores al mapear datos opcionales.
        this.idUbicacion = idUbicacion;
        this.idUsuario = idUsuario;
        this.latitud = latitud;
        this.longitud = longitud;
        this.descripcion = descripcion;
        this.direccion = direccion;
        this.activa = activa;
        this.estado = estado;
    }

    public void setDireccion(String direccion) {
        this.direccion = direccion;
    }

    public String getDireccion() {
        return direccion;
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

    public boolean isActiva() {
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

    public boolean isEmpty() {
        throw new UnsupportedOperationException("Not supported yet."); // Generated from nbfs://nbhost/SystemFileSystem/Templates/Classes/Code/GeneratedMethodBody
    }
}
