package com.mycompany.delivery.api.model;

public class PedidoConDetalle {
    private Pedido pedido;
    // Puedes agregar aquí la lista de detalles si es necesario
    // private List<DetallePedido> detalles;

    public Pedido getPedido() {
        return pedido;
    }

    public void setPedido(Pedido pedido) {
        this.pedido = pedido;
    }

    // Getters y setters para detalles si los necesitas
}
