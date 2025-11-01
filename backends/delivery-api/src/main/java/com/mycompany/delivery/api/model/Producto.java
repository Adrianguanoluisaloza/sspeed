package com.mycompany.delivery.api.model;

public class Producto {
    private int idProducto;
    private String nombre;
    private String descripcion;
    private double precio;
    private boolean disponible;
    private String imagenUrl;
    private String categoria;
    private int idCategoria;
    private Integer idNegocio;

    public Producto() {
    }

    public Producto(int idProducto, String nombre, String descripcion, double precio, boolean disponible, String imagenUrl, String categoria) {
        // Constructor completo para simplificar el mapeo directo desde JDBC.
        this.idProducto = idProducto;
        this.nombre = nombre;
        this.descripcion = descripcion;
        this.precio = precio;
        this.disponible = disponible;
        this.imagenUrl = imagenUrl;
        this.categoria = categoria;
    }

    public int getIdCategoria() {
        return idCategoria;
    }

    public void setIdCategoria(int idCategoria) {
        this.idCategoria = idCategoria;
    }

    public Integer getIdNegocio() {
        return idNegocio;
    }

    public void setIdNegocio(Integer idNegocio) {
        this.idNegocio = idNegocio;
    }

    public void setCategoria(String categoria) {
        this.categoria = categoria;
    }

    public String getCategoria() {
        return categoria;
    }

    public void setIdProducto(int idProducto) {
        this.idProducto = idProducto;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public void setDescripcion(String descripcion) {
        this.descripcion = descripcion;
    }

    public void setPrecio(double precio) {
        this.precio = precio;
    }

    public void setDisponible(boolean disponible) {
        this.disponible = disponible;
    }

    public void setImagenUrl(String imagenUrl) {
        this.imagenUrl = imagenUrl;
    }

    public int getIdProducto() {
        return idProducto;
    }

    public String getNombre() {
        return nombre;
    }

    public String getDescripcion() {
        return descripcion;
    }

    public double getPrecio() {
        return precio;
    }

    public boolean isDisponible() {
        return disponible;
    }

    public String getImagenUrl() {
        return imagenUrl;
    }
}
