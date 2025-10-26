package com.mycompany.delivery.api.model;

import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.List;

/**
 * Modelo que representa un pedido dentro del sistema Delivery.
 * Contiene detalles del cliente, delivery, ubicación, estado y totales.
 */
public class Pedido {

    private int idPedido;
    private int idCliente;
    private Integer idDelivery; // puede ser nulo
    private int idUbicacion;    // referencia a ubicaciones
    private String estado;      // pendiente, en_camino, entregado, cancelado
    private double total;
    private String direccionEntrega;
    private String metodoPago;  // efectivo, tarjeta, transferencia, etc.
    private Timestamp fechaPedido;
    private Timestamp fechaEntrega; // opcional

    private List<DetallePedido> detalles = new ArrayList<>();

    // ===========================
    // CONSTRUCTORES
    // ===========================
    public Pedido() {
    }

    public Pedido(int idPedido, int idCliente, Integer idDelivery, int idUbicacion, String estado, double total,
                  String direccionEntrega, String metodoPago, Timestamp fechaPedido, Timestamp fechaEntrega) {
        this.idPedido = idPedido;
        this.idCliente = idCliente;
        this.idDelivery = idDelivery;
        this.idUbicacion = idUbicacion;
        this.estado = estado;
        this.total = total;
        this.direccionEntrega = direccionEntrega;
        this.metodoPago = metodoPago;
        this.fechaPedido = fechaPedido;
        this.fechaEntrega = fechaEntrega;
    }

    // ===========================
    // GETTERS Y SETTERS
    // ===========================

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

    public Integer getIdDelivery() {
        return idDelivery;
    }

    public void setIdDelivery(Integer idDelivery) {
        this.idDelivery = idDelivery;
    }

    public int getIdUbicacion() {
        return idUbicacion;
    }

    public void setIdUbicacion(int idUbicacion) {
        this.idUbicacion = idUbicacion;
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

    public Timestamp getFechaEntrega() {
        return fechaEntrega;
    }

    public void setFechaEntrega(Timestamp fechaEntrega) {
        this.fechaEntrega = fechaEntrega;
    }

    public List<DetallePedido> getDetalles() {
        return detalles;
    }

    public void setDetalles(List<DetallePedido> detalles) {
        this.detalles = detalles;
    }

    // ===========================
    // MÉTODOS AUXILIARES
    // ===========================

    public boolean isAsignado() {
        return idDelivery != null && idDelivery > 0;
    }

    public boolean isEntregado() {
        return "entregado".equalsIgnoreCase(estado);
    }

    public boolean isPendiente() {
        return "pendiente".equalsIgnoreCase(estado);
    }

    public void agregarDetalle(DetallePedido detalle) {
        if (detalle != null) {
            this.detalles.add(detalle);
        }
    }

    @Override
    public String toString() {
        return "Pedido{" +
                "idPedido=" + idPedido +
                ", idCliente=" + idCliente +
                ", idDelivery=" + idDelivery +
                ", idUbicacion=" + idUbicacion +
                ", estado='" + estado + '\'' +
                ", total=" + total +
                ", direccionEntrega='" + direccionEntrega + '\'' +
                ", metodoPago='" + metodoPago + '\'' +
                ", fechaPedido=" + fechaPedido +
                ", fechaEntrega=" + fechaEntrega +
                '}';
    }
}