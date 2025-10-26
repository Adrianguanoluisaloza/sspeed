package com.mycompany.delivery.api.controller;

import com.mycompany.delivery.api.model.DetallePedido;
import com.mycompany.delivery.api.model.Pedido;
import com.mycompany.delivery.api.repository.PedidoRepository;
import com.mycompany.delivery.api.util.ApiException;
import com.mycompany.delivery.api.util.ApiResponse;
import java.sql.SQLException;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Controlador que aplica reglas de negocio sobre pedidos antes de hablar con la base de datos.
 */
public class PedidoController {

    private static final List<String> ESTADOS_VALIDOS = List.of("pendiente", "en preparacion", "en camino", "entregado", "cancelado");
    private final PedidoRepository repo = new PedidoRepository();

    public ApiResponse<List<Pedido>> getPedidos() {
        try {
            return ApiResponse.success(200, "Pedidos recuperados", repo.listarPedidos());
        } catch (SQLException e) {
            System.err.println("❌ Error listando pedidos: " + e.getMessage());
            throw new ApiException(500, "No se pudieron obtener los pedidos", e);
        }
    }

    public ApiResponse<Pedido> getPedido(int id) {
        if (id <= 0) {
            throw new ApiException(400, "Identificador de pedido inválido");
        }
        try {
            Optional<Pedido> pedido = repo.obtenerPedido(id);
            if (pedido.isEmpty()) {
                throw new ApiException(404, "Pedido no encontrado");
            }
            return ApiResponse.success("Pedido obtenido", pedido.get());
        } catch (SQLException e) {
            System.err.println("❌ Error obteniendo pedido: " + e.getMessage());
            throw new ApiException(500, "No se pudo obtener el pedido", e);
        }
    }

    public ApiResponse<Map<String, Object>> getPedidoConDetalles(int id) {
        if (id <= 0) {
            throw new ApiException(400, "Identificador de pedido inválido");
        }
        try {
            Optional<Map<String, Object>> pedido = repo.obtenerPedidoConDetalles(id);
            if (pedido.isEmpty()) {
                throw new ApiException(404, "Pedido no encontrado");
            }
            return ApiResponse.success("Pedido con detalles", pedido.get());
        } catch (SQLException e) {
            System.err.println("❌ Error obteniendo pedido con detalles: " + e.getMessage());
            throw new ApiException(500, "No se pudo obtener el detalle del pedido", e);
        }
    }

    public ApiResponse<Pedido> crearPedido(Pedido pedido, List<DetallePedido> detalles) {
        validarPedido(pedido, detalles);
        try {
            int idPedido = repo.crearPedido(pedido, detalles);
            pedido.setIdPedido(idPedido);
            System.out.println("ℹ️ Pedido creado: " + idPedido);
            return ApiResponse.success(201, "Pedido creado correctamente", pedido);
        } catch (SQLException e) {
            System.err.println("❌ Error creando pedido: " + e.getMessage());
            throw new ApiException(500, "No se pudo crear el pedido", e);
        }
    }

    public ApiResponse<List<Pedido>> getPedidosPorEstado(String estado) {
        String estadoNormalizado = normalizarEstado(estado);
        try {
            return ApiResponse.success(200, "Pedidos filtrados", repo.listarPedidosPorEstado(estadoNormalizado));
        } catch (SQLException e) {
            System.err.println("❌ Error filtrando pedidos: " + e.getMessage());
            throw new ApiException(500, "No se pudieron obtener los pedidos", e);
        }
    }

    public ApiResponse<List<Pedido>> getPedidosPorCliente(int idCliente) {
        if (idCliente <= 0) {
            throw new ApiException(400, "Identificador de cliente inválido");
        }
        try {
            return ApiResponse.success(200, "Pedidos del cliente", repo.listarPedidosPorCliente(idCliente));
        } catch (SQLException e) {
            System.err.println("❌ Error listando pedidos por cliente: " + e.getMessage());
            throw new ApiException(500, "No se pudieron obtener los pedidos del cliente", e);
        }
    }

    public ApiResponse<Void> updateEstadoPedido(int id, String estado) {
        if (id <= 0) {
            throw new ApiException(400, "Identificador de pedido inválido");
        }
        String estadoNormalizado = normalizarEstado(estado);
        try {
            boolean actualizado = repo.actualizarEstadoPedido(id, estadoNormalizado);
            if (!actualizado) {
                throw new ApiException(404, "Pedido no encontrado para actualizar");
            }
            System.out.println("ℹ️ Estado de pedido actualizado: " + id + " -> " + estadoNormalizado);
            return ApiResponse.success("Estado actualizado correctamente");
        } catch (SQLException e) {
            System.err.println("❌ Error actualizando estado: " + e.getMessage());
            throw new ApiException(500, "No se pudo actualizar el pedido", e);
        }
    }

    public ApiResponse<List<Pedido>> getPedidosDisponibles() {
        try {
            return ApiResponse.success(200, "Pedidos disponibles", repo.listarPedidosDisponibles());
        } catch (SQLException e) {
            System.err.println("❌ Error listando pedidos disponibles: " + e.getMessage());
            throw new ApiException(500, "No se pudieron obtener los pedidos disponibles", e);
        }
    }

    public ApiResponse<Void> asignarPedido(int idPedido, int idDelivery) {
        if (idPedido <= 0 || idDelivery <= 0) {
            throw new ApiException(400, "Identificadores inválidos para asignar");
        }
        try {
            boolean asignado = repo.asignarDelivery(idPedido, idDelivery);
            if (!asignado) {
                throw new ApiException(409, "El pedido ya tiene repartidor o no existe");
            }
            System.out.println("ℹ️ Pedido asignado: " + idPedido + " -> delivery " + idDelivery);
            return ApiResponse.success("Pedido asignado correctamente");
        } catch (SQLException e) {
            System.err.println("❌ Error asignando pedido: " + e.getMessage());
            throw new ApiException(500, "No se pudo asignar el pedido", e);
        }
    }

    public ApiResponse<List<Pedido>> getPedidosPorDelivery(int idDelivery) {
        if (idDelivery <= 0) {
            throw new ApiException(400, "Identificador de repartidor inválido");
        }
        try {
            return ApiResponse.success(200, "Pedidos del repartidor", repo.listarPedidosPorDelivery(idDelivery));
        } catch (SQLException e) {
            System.err.println("❌ Error listando pedidos por delivery: " + e.getMessage());
            throw new ApiException(500, "No se pudieron obtener los pedidos del repartidor", e);
        }
    }

    private void validarPedido(Pedido pedido, List<DetallePedido> detalles) {
        if (pedido == null) {
            throw new ApiException(400, "El pedido es obligatorio");
        }
        if (pedido.getIdCliente() <= 0) {
            throw new ApiException(400, "El cliente es obligatorio");
        }
        if (pedido.getDireccionEntrega() == null || pedido.getDireccionEntrega().isBlank()) {
            throw new ApiException(400, "La dirección de entrega es obligatoria");
        }
        if (pedido.getMetodoPago() == null || pedido.getMetodoPago().isBlank()) {
            throw new ApiException(400, "El método de pago es obligatorio");
        }
        if (detalles == null || detalles.isEmpty()) {
            throw new ApiException(400, "Debe incluir al menos un producto en el pedido");
        }
        for (DetallePedido detalle : detalles) {
            if (detalle.getIdProducto() <= 0 || detalle.getCantidad() <= 0) {
                throw new ApiException(400, "Los productos del pedido son inválidos");
            }
            if (detalle.getPrecioUnitario() <= 0 || detalle.getSubtotal() <= 0) {
                // Validamos importes positivos para evitar tickets inconsistentes en el app Flutter.
                throw new ApiException(400, "Los importes de los productos deben ser mayores a cero");
            }
        }
        if (pedido.getTotal() <= 0) {
            throw new ApiException(400, "El total del pedido debe ser mayor a cero");
        }
        if (pedido.getEstado() == null || pedido.getEstado().isBlank()) {
            pedido.setEstado("pendiente");
        } else {
            pedido.setEstado(normalizarEstado(pedido.getEstado()));
        }
    }

    private String normalizarEstado(String estado) {
        if (estado == null) {
            throw new ApiException(400, "El estado es obligatorio");
        }
        String limpio = estado.trim().toLowerCase();
        if (!ESTADOS_VALIDOS.contains(limpio)) {
            throw new ApiException(400, "Estado de pedido inválido");
        }
        return limpio;
    }

    public ApiResponse<java.util.Map<String, Object>> getEstadisticasDelivery(int idDelivery) {
        if (idDelivery <= 0) {
            throw new ApiException(400, "Identificador de repartidor inválido");
        }
        try {
            java.util.Map<String, Object> stats = repo.obtenerEstadisticasDelivery(idDelivery);
            return ApiResponse.success(200, "Estadísticas del repartidor", stats);
        } catch (SQLException e) {
            System.err.println("Error obteniendo estadísticas de delivery: " + e.getMessage());
            throw new ApiException(500, "No se pudieron obtener las estadísticas del repartidor", e);
        }
    }
}
