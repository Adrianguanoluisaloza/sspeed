package com.mycompany.delivery.api.util;

import java.time.LocalTime;

public final class ChatBotResponder {

    private ChatBotResponder() {
    }

    public static String replyTo(String rawMessage) {
        String message = rawMessage == null ? "" : rawMessage.trim().toLowerCase();

        if (message.isBlank()) {
            return "Hola, puedo ayudarte con tu pedido. Cuentame tu consulta.";
        }

        if (message.contains("hola") || message.contains("buenos dias") || message.contains("buenas tardes")) {
            return saludo();
        }
        if (message.contains("pedido") && message.contains("estado")) {
            return "Puedes revisar el estado actual en la pantalla Mis pedidos. Te avisaremos cuando cambie a en camino.";
        }
        if (message.contains("tardar") || message.contains("cuando llega")) {
            return "El pedido suele tardar entre veinte y treinta minutos. Si hay un retraso enviaremos una notificacion.";
        }
        if (message.contains("cancelar")) {
            return "Si deseas cancelar usa el boton Cancelar dentro del detalle mientras el pedido siga en preparacion.";
        }
        if (message.contains("gracias") || message.contains("thank")) {
            return "Con gusto. Si necesitas algo mas sobre la entrega, dime.";
        }
        return "Estoy aqui para ayudarte con tu compra. Pregunta por el estado del pedido, tiempos de entrega o como cancelar.";
    }

    private static String saludo() {
        int hour = LocalTime.now().getHour();
        if (hour < 12) {
            return "Buenos dias, en que puedo ayudarte con la entrega?";
        }
        if (hour < 19) {
            return "Hola, estoy pendiente de tu pedido. Que necesitas saber?";
        }
        return "Buenas noches. Si quieres revisar el estado o reportar un problema, dime y te ayudo.";
    }
}
