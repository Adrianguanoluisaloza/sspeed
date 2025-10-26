package com.mycompany.delivery.api.model;

import java.sql.Timestamp;

public class Pedido {

    private int idPedido;
    private int idCliente;
    private int idDelivery;
    private String estado;
    private double total;
    private String direccionEntrega;
    private String metodoPago;
    private Timestamp fechaPedido;

    public Pedido() {
    }

    public Pedido(int idPedido, int idCliente, int idDelivery, String estado, double total, String direccionEntrega, String metodoPago, Timestamp fechaPedido) {
        // Constructor completo para mapear filas de pedidos sin dejar campos vacíos.
        this.idPedido = idPedido;
        this.idCliente = idCliente;
        this.idDelivery = idDelivery;
        this.estado = estado;
        this.total = total;
        this.direccionEntrega = direccionEntrega;
        this.metodoPago = metodoPago;
        this.fechaPedido = fechaPedido;
    }

    public int getIdPedido() {
        return idPedido;
    }

    public void setIdPedido(int idPedido) {
        this.idPedido = idPedido;
    }

    public int getIdCliente() {
        return idCliente;
    }

    public void setIdCliente(int idCliente) {
        this.idCliente = idCliente;
    }

    public int getIdDelivery() {
        return idDelivery;
    }

    public void setIdDelivery(int idDelivery) {
        this.idDelivery = idDelivery;
    }

    public String getEstado() {
        return estado;
    }

    public void setEstado(String estado) {
        this.estado = estado;
    }

    public double getTotal() {
        return total;
    }

    public void setTotal(double total) {
        this.total = total;
    }

    public String getDireccionEntrega() {
        return direccionEntrega;
    }

    public void setDireccionEntrega(String direccionEntrega) {
        this.direccionEntrega = direccionEntrega;
    }

    public String getMetodoPago() {
        return metodoPago;
    }

    public void setMetodoPago(String metodoPago) {
        this.metodoPago = metodoPago;
    }

    public Timestamp getFechaPedido() {
        return fechaPedido;
    }

    public void setFechaPedido(Timestamp fechaPedido) {
        this.fechaPedido = fechaPedido;
    }
}
