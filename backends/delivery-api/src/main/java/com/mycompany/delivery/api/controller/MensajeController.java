package com.mycompany.delivery.api.controller;

import com.mycompany.delivery.api.model.Mensaje;
import com.mycompany.delivery.api.repository.MensajeRepository;
import com.mycompany.delivery.api.util.ApiException;
import com.mycompany.delivery.api.util.ApiResponse;

import java.sql.SQLException;
import java.util.List;

/**
 * Controlador que gestiona el envío y recuperación de mensajes
 * asociados a pedidos o chats entre cliente y repartidor.
 */
public class MensajeController {

    private final MensajeRepository repo = new MensajeRepository();

    // ===========================
    // ENVIAR MENSAJE
    // ===========================
    public ApiResponse<Void> enviarMensaje(Mensaje mensaje) {
        if (mensaje == null) throw new ApiException(400, "Mensaje inválido");
        if (mensaje.getIdPedido() <= 0 || mensaje.getIdRemitente() <= 0 || mensaje.getMensaje() == null || mensaje.getMensaje().isBlank()) {
            throw new ApiException(400, "Faltan datos requeridos del mensaje");
        }
        try {
            boolean ok = repo.insertarMensaje(mensaje);
            if (!ok) throw new ApiException(500, "No se pudo guardar el mensaje");
            return ApiResponse.success("Mensaje enviado correctamente");
        } catch (SQLException e) {
            throw new ApiException(500, "Error al enviar el mensaje", e);
        }
    }

    // ===========================
    // OBTENER MENSAJES POR PEDIDO
    // ===========================
    public ApiResponse<List<Mensaje>> getMensajesPorPedido(int idPedido) {
        if (idPedido <= 0) throw new ApiException(400, "Identificador de pedido inválido");
        try {
            List<Mensaje> mensajes = repo.obtenerMensajesPorPedido(idPedido);
            return ApiResponse.success(200, "Mensajes obtenidos", mensajes);
        } catch (SQLException e) {
            throw new ApiException(500, "Error al obtener mensajes", e);
        }
    }
}
