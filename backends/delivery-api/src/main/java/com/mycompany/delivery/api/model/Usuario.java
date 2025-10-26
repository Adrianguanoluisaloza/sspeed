package com.mycompany.delivery.api.model;

import java.sql.Timestamp;

/**
 * Modelo que representa la tabla 'usuarios'.
 */
public class Usuario {

    private int idUsuario;
    private String nombre;
    private String correo;
    private String contrasena; // Con 'n'
    private String rol;
    private String telefono;
    private boolean activo; // Coincide con la columna 'activo'
    private Timestamp fechaRegistro;

    public Usuario() {
    }

    public Usuario(int idUsuario, String nombre, String correo, String contrasena, String rol, String telefono, boolean activo, Timestamp fechaRegistro) {
        // Constructor útil para mapear resultados JDBC sin exponer setters innecesarios.
        this.idUsuario = idUsuario;
        this.nombre = nombre;
        this.correo = correo;
        this.contrasena = contrasena;
        this.rol = rol;
        this.telefono = telefono;
        this.activo = activo;
        this.fechaRegistro = fechaRegistro;
    }

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

    public String getRol() {
        return rol;
    }

    public void setRol(String rol) {
        this.rol = rol;
    }

    public String getTelefono() {
        return telefono;
    }

    public void setTelefono(String telefono) {
        this.telefono = telefono;
    }

    public boolean isActivo() {
        return activo;
    }

    public void setActivo(boolean activo) {
        this.activo = activo;
    }

    public Timestamp getFechaRegistro() {
        return fechaRegistro;
    }

    public void setFechaRegistro(Timestamp fechaRegistro) {
        this.fechaRegistro = fechaRegistro;
    }
}
