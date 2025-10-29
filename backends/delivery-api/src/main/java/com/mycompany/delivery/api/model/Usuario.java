package com.mycompany.delivery.api.model;

import java.util.HashMap;
import java.util.Map;

/**
 * Modelo que representa a un usuario dentro del sistema Delivery.
 * Compatible con controladores y repositorios actualizados.
 */
public class Usuario {

    private int idUsuario;
    private String nombre;
    private String correo;
    private String contrasena;
    private String telefono;
    private String rol; // cliente, admin, delivery, etc.
    private boolean activo = true;

    // ===========================
    // CONSTRUCTORES
    // ===========================
    public Usuario() {
    }

    public Usuario(int idUsuario, String nombre, String correo, String contrasena, String telefono, String rol, boolean activo) {
        this.idUsuario = idUsuario;
        this.nombre = nombre;
        this.correo = correo;
        this.contrasena = contrasena;
        this.telefono = telefono;
        this.rol = rol;
        this.activo = activo;
    }

    // ===========================
    // GETTERS Y SETTERS
    // ===========================

    public int getIdUsuario() {
        return idUsuario;
    }

    public void setIdUsuario(int idUsuario) {
        this.idUsuario = idUsuario;
    }

    public String getNombre() {
        return nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public String getCorreo() {
        return correo;
    }

    public void setCorreo(String correo) {
        this.correo = correo;
    }

    public String getContrasena() {
        return contrasena;
    }

    public void setContrasena(String contrasena) {
        this.contrasena = contrasena;
    }

    public String getTelefono() {
        return telefono;
    }

    public void setTelefono(String telefono) {
        this.telefono = telefono;
    }

    public String getRol() {
        return rol;
    }

    public void setRol(String rol) {
        this.rol = rol;
    }

    public boolean isActivo() {
        return activo;
    }

    public void setActivo(boolean activo) {
        this.activo = activo;
    }

    // ===========================
    // MÉTODOS AUXILIARES
    // ===========================

    public boolean isAdmin() {
        return "admin".equalsIgnoreCase(rol);
    }

    public boolean isDelivery() {
        return "delivery".equalsIgnoreCase(rol);
    }

    public boolean isCliente() {
        return "cliente".equalsIgnoreCase(rol);
    }

    @Override
    public String toString() {
        return "Usuario{" +
                "idUsuario=" + idUsuario +
                ", nombre='" + nombre + '\'' +
                ", correo='" + correo + '\'' +
                ", telefono='" + telefono + '\'' +
                ", rol='" + rol + '\'' +
                ", activo=" + activo +
                '}';
    }

        /**
         * Devuelve los datos del usuario como un Map.
         */
        public Map<String, Object> toMap() {
            Map<String, Object> map = new HashMap<>();
            map.put("idUsuario", idUsuario);
            map.put("nombre", nombre);
            map.put("correo", correo);
            map.put("telefono", telefono);
            map.put("rol", rol);
            map.put("activo", activo);
            return map;
        }
}