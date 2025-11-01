package com.mycompany.delivery.api.model;

public class RespuestaSoporte {

    private int idRespuesta;
    private String categoria;
    private String mensaje;
    private int prioridad;
    private boolean conMarca;

    public int getIdRespuesta() {
        return idRespuesta;
    }

    public void setIdRespuesta(int idRespuesta) {
        this.idRespuesta = idRespuesta;
    }

    public String getCategoria() {
        return categoria;
    }

    public void setCategoria(String categoria) {
        this.categoria = categoria;
    }

    public String getMensaje() {
        return mensaje;
    }

    public void setMensaje(String mensaje) {
        this.mensaje = mensaje;
    }

    public int getPrioridad() {
        return prioridad;
    }

    public void setPrioridad(int prioridad) {
        this.prioridad = prioridad;
    }

    public boolean isConMarca() {
        return conMarca;
    }

    public void setConMarca(boolean conMarca) {
        this.conMarca = conMarca;
    }
}
