package com.mycompany.delivery.api.services;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import com.google.genai.Client;
import com.google.genai.errors.ClientException;
import com.google.genai.types.Content;
import com.google.genai.types.GenerateContentResponse;
import com.google.genai.types.Part;
import io.github.cdimascio.dotenv.Dotenv;

/**
 * Servicio de integración con la API de Gemini utilizando el SDK oficial
 * {@code google-genai}. Construye el contexto de conversación y obtiene la
 * respuesta del modelo seleccionado.
 */
public class GeminiService implements AutoCloseable {

    private static final String DEFAULT_MODEL_NAME = "gemini-1.5-flash-001";
    private static final String FALLBACK_MESSAGE =
            "Lo siento, mi cerebro (IA) no esta disponible en este momento. Por favor, contacta a soporte.";

    private final Client client;

    public GeminiService() {
        String apiKey = resolveApiKey();
        if (apiKey == null || apiKey.isBlank()) {
            System.err.println("[ERROR] La variable de entorno GEMINI_API_KEY no está configurada.");
            this.client = null;
        } else {
            this.client = Client.builder().apiKey(apiKey).build();
        }
    }

    private String resolveApiKey() {
        String key = System.getenv("GEMINI_API_KEY");
        if (key != null && !key.isBlank()) {
            return key;
        }
        key = System.getProperty("GEMINI_API_KEY");
        if (key != null && !key.isBlank()) {
            return key;
        }
        try {
            Dotenv dotenv = Dotenv.configure()
                    .directory("../delivery-api")
                    .ignoreIfMalformed()
                    .ignoreIfMissing()
                    .load();
            key = dotenv.get("GEMINI_API_KEY");
            if (key != null && !key.isBlank()) {
                return key;
            }
        } catch (Exception ignored) {
        }
        return null;
    }

    public String generateReply(String prompt, List<Map<String, Object>> history, int currentUserId) {
        if (client == null) {
            return FALLBACK_MESSAGE;
        }

        List<Content> requestContents = new ArrayList<>();

        // Mensaje de contexto para mantener el rol del asistente.
        requestContents.add(buildContent("user",
                "Eres CIA Bot, un asistente virtual amigable y servicial para una app de delivery de comida. "
                        + "Tu objetivo es ayudar a los usuarios con sus dudas sobre pedidos, la app, o simplemente "
                        + "conversar de forma amena. Se breve y directo."));
        requestContents.add(buildContent("model", "Entendido. Estoy listo para ayudar."));

        // Historial de conversación.
        if (history != null) {
            for (Map<String, Object> msg : history) {
                if (msg == null) {
                    continue;
                }
                Object remitenteObj = msg.get("id_remitente");
                Object mensajeObj = msg.get("mensaje");
                if (mensajeObj == null) {
                    continue;
                }
                int idRemitente = remitenteObj instanceof Number ? ((Number) remitenteObj).intValue() : -1;
                String role = (idRemitente == currentUserId) ? "user" : "model";
                String texto = mensajeObj.toString();
                if (texto != null && !texto.isBlank()) {
                    requestContents.add(buildContent(role, texto));
                }
            }
        }

        // Mensaje actual del usuario.
        String safePrompt = prompt == null ? "" : prompt;
        requestContents.add(buildContent("user", safePrompt));

        try {
            String modelName = resolveModelName();
            GenerateContentResponse response = client.models.generateContent(modelName, requestContents, null);
            String reply = response != null ? response.text() : null;
            if (reply == null || reply.isBlank()) {
                return "No entendi la respuesta. Podrias preguntar de otra forma?";
            }
            return reply;
        } catch (ClientException e) {
            System.err.println("Error en la API de Gemini: " + e.getMessage());
            return "Tuve un problema para procesar tu solicitud. Intentalo de nuevo.";
        } catch (Exception e) {
            System.err.println("Excepción inesperada al llamar a la API de Gemini: " + e.getMessage());
            return "No pude conectarme para generar una respuesta. Revisa tu conexion.";
        }
    }

    private Content buildContent(String role, String text) {
        return Content.builder()
                .role(role)
                .parts(List.of(Part.fromText(text)))
                .build();
    }

    private String resolveModelName() {
        String model = System.getenv("GEMINI_MODEL");
        if (model != null && !model.isBlank()) {
            return model;
        }
        model = System.getProperty("GEMINI_MODEL");
        if (model != null && !model.isBlank()) {
            return model;
        }
        try {
            Dotenv dotenv = Dotenv.configure()
                    .directory("../delivery-api")
                    .ignoreIfMalformed()
                    .ignoreIfMissing()
                    .load();
            model = dotenv.get("GEMINI_MODEL");
            if (model != null && !model.isBlank()) {
                return model;
            }
        } catch (Exception ignored) {
        }
        return DEFAULT_MODEL_NAME;
    }

    @Override
    public void close() {
        if (client != null) {
            client.close();
        }
    }
}
