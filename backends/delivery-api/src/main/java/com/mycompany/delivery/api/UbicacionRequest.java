
package com.mycompany.delivery.api;

/**
 * DTO (Data Transfer Object) que representa la solicitud de ubicación enviada desde el cliente Flutter.
 * Se usa para crear, actualizar o eliminar ubicaciones.
 */
public class UbicacionRequest {

    private Integer idUsuario;       // ID del usuario (FK con usuarios)
    private Double latitud;          // Latitud de la ubicación
    private Double longitud;         // Longitud de la ubicación
    private String direccion;        // Dirección escrita
    private String descripcion;      // Nombre de la ubicación (Casa, Oficina, etc.)
    private Boolean activa = Boolean.TRUE;      // Si la ubicación está activa

    // --- Constructores ---
    public UbicacionRequest() {
    }

    public UbicacionRequest(int idUsuario, double latitud, double longitud, String direccion, String descripcion, boolean activa) {
        this.idUsuario = idUsuario;
        this.latitud = latitud;
        this.longitud = longitud;
        this.direccion = direccion;
        this.descripcion = descripcion;
        this.activa = activa;
    }

    // --- Getters y Setters ---
    public Integer getIdUsuario() {
        return idUsuario;
    }

    public void setIdUsuario(Integer idUsuario) {
        this.idUsuario = idUsuario;
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

    public String getDireccion() {
        return direccion;
    }

    public void setDireccion(String direccion) {
        this.direccion = direccion;
    }

    public String getDescripcion() {
        return descripcion;
    }

    public void setDescripcion(String descripcion) {
        this.descripcion = descripcion;
    }

    public Boolean getActiva() {
        return activa;
    }

    public boolean isActiva() {
        return Boolean.TRUE.equals(activa);
    }

    public void setActiva(Boolean activa) {
        this.activa = activa;
    }

    @Override
    public String toString() {
        return "UbicacionRequest{" +
                "idUsuario=" + idUsuario +
                ", latitud=" + latitud +
                ", longitud=" + longitud +
                ", direccion='" + direccion + '\'' +
                ", descripcion='" + descripcion + '\'' +
                ", activa=" + activa +
                '}';
    }
}
