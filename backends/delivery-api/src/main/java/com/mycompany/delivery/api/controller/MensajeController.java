package com.mycompany.delivery.api.controller;

import com.mycompany.delivery.api.model.Mensaje;
import com.mycompany.delivery.api.repository.MensajeRepository;
import com.mycompany.delivery.api.util.ApiException;
import com.mycompany.delivery.api.util.ApiResponse;
import java.sql.SQLException;
import java.util.List;

/**
 * Controlador de mensajes con validaciones básicas para evitar datos vacíos.
 */
public class MensajeController {

    private final MensajeRepository repo = new MensajeRepository();

    public ApiResponse<Void> enviarMensaje(Mensaje mensaje) {
        validarMensaje(mensaje);
        try {
            boolean enviado = repo.enviarMensaje(mensaje);
            if (!enviado) {
                throw new ApiException(500, "No se pudo enviar el mensaje");
            }
            System.out.println("ℹ️ Mensaje enviado para pedido: " + mensaje.getIdPedido());
            return ApiResponse.success(201, "Mensaje enviado", null);
        } catch (SQLException e) {
            System.err.println("❌ Error guardando mensaje: " + e.getMessage());
            throw new ApiException(500, "Error al enviar el mensaje", e);
        }
    }

    public ApiResponse<List<Mensaje>> getMensajesPorPedido(int idPedido) {
        if (idPedido <= 0) {
            throw new ApiException(400, "Identificador de pedido inválido");
        }
        try {
            List<Mensaje> mensajes = repo.listarMensajesPorPedido(idPedido);
            return ApiResponse.success(200, "Mensajes recuperados", mensajes);
        } catch (SQLException e) {
            System.err.println("❌ Error consultando mensajes: " + e.getMessage());
            throw new ApiException(500, "No se pudieron obtener los mensajes", e);
        }
    }

    private void validarMensaje(Mensaje mensaje) {
        if (mensaje == null) {
            throw new ApiException(400, "El cuerpo de la solicitud es obligatorio");
        }
        if (mensaje.getIdPedido() <= 0) {
            throw new ApiException(400, "El pedido es obligatorio");
        }
        if (mensaje.getIdRemitente() <= 0) {
            throw new ApiException(400, "El remitente es obligatorio");
        }
        if (mensaje.getMensaje() == null || mensaje.getMensaje().isBlank()) {
            throw new ApiException(400, "El mensaje no puede estar vacío");
        }
    }
}
