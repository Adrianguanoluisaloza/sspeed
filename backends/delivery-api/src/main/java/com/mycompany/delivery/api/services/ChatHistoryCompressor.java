package com.mycompany.delivery.api.services;

import java.util.List;
import java.util.stream.Collectors;

public class ChatHistoryCompressor {

    public static String buildPromptWithHistory(String systemPrompt,
                                                String resumenPrevio,
                                                List<String> ultimosMensajes,
                                                String mensajeActual) {

        StringBuilder prompt = new StringBuilder();
        prompt.append(systemPrompt).append("\n\n");

        if (resumenPrevio != null && !resumenPrevio.isBlank()) {
            prompt.append("Resumen anterior:\n").append(resumenPrevio).append("\n\n");
        }

        if (ultimosMensajes != null && !ultimosMensajes.isEmpty()) {
            prompt.append("Últimos mensajes:\n");
            prompt.append(
                    ultimosMensajes.stream()
                            .map(m -> "- " + m)
                            .collect(Collectors.joining("\n"))
            );
            prompt.append("\n\n");
        }

        prompt.append("Usuario: ").append(mensajeActual).append("\n");
        prompt.append("Responde como asistente:");

        return prompt.toString();
    }
}
