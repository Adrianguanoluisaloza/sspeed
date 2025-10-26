package com.mycompany.delivery.api.model;

/**
 * Representa el detalle de un producto dentro de un pedido.
 * Incluye precio unitario y subtotal para simplificar el cálculo total en el backend.
 */
public class DetallePedido {

    private int idDetalle;
    private int idPedido;
    private int idProducto;
    private int cantidad;
    private double precioUnitario;
    private double subtotal;

    // ===========================
    // CONSTRUCTORES
    // ===========================
    public DetallePedido() {
    }

    public DetallePedido(int idDetalle, int idPedido, int idProducto, int cantidad, double precioUnitario, double subtotal) {
        this.idDetalle = idDetalle;
        this.idPedido = idPedido;
        this.idProducto = idProducto;
        this.cantidad = cantidad;
        this.precioUnitario = precioUnitario;
        this.subtotal = subtotal;
    }

    // ===========================
    // GETTERS Y SETTERS
    // ===========================

    public int getIdDetalle() {
        return idDetalle;
    }

    public void setIdDetalle(int idDetalle) {
        this.idDetalle = idDetalle;
    }

    public int getIdPedido() {
        return idPedido;
    }

    public void setIdPedido(int idPedido) {
        this.idPedido = idPedido;
    }

    public int getIdProducto() {
        return idProducto;
    }

    public void setIdProducto(int idProducto) {
        this.idProducto = idProducto;
    }

    public int getCantidad() {
        return cantidad;
    }

    public void setCantidad(int cantidad) {
        this.cantidad = cantidad;
    }

    public double getPrecioUnitario() {
        return precioUnitario;
    }

    public void setPrecioUnitario(double precioUnitario) {
        this.precioUnitario = precioUnitario;
    }

    public double getSubtotal() {
        return subtotal;
    }

    public void setSubtotal(double subtotal) {
        this.subtotal = subtotal;
    }

    // ===========================
    // MÉTODOS AUXILIARES
    // ===========================

    public double calcularSubtotal() {
        return this.precioUnitario * this.cantidad;
    }

    @Override
    public String toString() {
        return "DetallePedido{" +
                "idDetalle=" + idDetalle +
                ", idPedido=" + idPedido +
                ", idProducto=" + idProducto +
                ", cantidad=" + cantidad +
                ", precioUnitario=" + precioUnitario +
                ", subtotal=" + subtotal +
                '}';
    }
}
