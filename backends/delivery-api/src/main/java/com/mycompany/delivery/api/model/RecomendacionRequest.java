package com.mycompany.delivery.api.model;

/**
 * DTO para recibir los datos de una nueva recomendación/reseña desde Flutter.
 */
public class RecomendacionRequest {
    private int idUsuario;
    private int puntuacion; // 1 a 5 estrellas
    private String comentario;

    // Getters (necesarios para que Gson funcione)
    public int getIdUsuario() {
        return idUsuario;
    }

    public int getPuntuacion() {
        return puntuacion;
    }

    public String getComentario() {
        return comentario;
    }

    // Setters (opcionales, pero buena práctica)
    public void setIdUsuario(int idUsuario) {
        this.idUsuario = idUsuario;
    }

    public void setPuntuacion(int puntuacion) {
        this.puntuacion = puntuacion;
    }

    public void setComentario(String comentario) {
        this.comentario = comentario;
    }
}
