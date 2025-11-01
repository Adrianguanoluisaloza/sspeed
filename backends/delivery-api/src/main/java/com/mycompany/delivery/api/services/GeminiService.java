package com.mycompany.delivery.api.services;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import io.github.cdimascio.dotenv.Dotenv;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Servicio ligero que consume la API de Gemini (Generative Language) v1
 * empleando {@link java.net.http.HttpClient}. Construye un payload compatible
 * con el endpoint /v1/models/:generateContent.
 */
public final class GeminiService {

    private static final String DEFAULT_MODEL_NAME = "gemini-2.0-flash-live";
    private static final String FALLBACK_MESSAGE =
            "Lo siento, mi cerebro (IA) no esta disponible en este momento. Por favor, contacta a soporte.";

    private static final Gson GSON = new Gson();
    private static final HttpClient HTTP_CLIENT = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    private final String apiKey;
    private final String modelName;

    public GeminiService() {
        this.apiKey = resolveApiKey();
        this.modelName = resolveModelName();
    }

    /**
     * Genera una respuesta a partir del prompt y la conversacion previa.
     *
     * @param prompt        Mensaje actual del usuario.
     * @param history       Historial de mensajes (cada elemento debe contener al menos
     *                      las claves "id_remitente" y "mensaje").
     * @param currentUserId Identificador del usuario actual (para determinar su rol).
     * @return Texto devuelto por Gemini o un mensaje alternativo si no fue posible.
     */
    public String generateReply(String prompt,
                                List<Map<String, Object>> history,
                                int currentUserId) {
        if (apiKey == null || apiKey.isBlank()) {
            return FALLBACK_MESSAGE;
        }

        final String safePrompt = prompt == null ? "" : prompt.trim();
        if (safePrompt.isEmpty()) {
            return "Podrias indicarme tu consulta?";
        }

        try {
            JsonObject requestPayload = buildPayload(safePrompt, history, currentUserId);
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(String.format(
                            "https://generativelanguage.googleapis.com/v1/models/%s:generateContent?key=%s",
                            modelName, apiKey)))
                    .header("Content-Type", "application/json")
                    .timeout(Duration.ofSeconds(30))
                    .POST(HttpRequest.BodyPublishers.ofString(GSON.toJson(requestPayload)))
                    .build();

            HttpResponse<String> response = HTTP_CLIENT.send(
                    request,
                    HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() != 200) {
                System.err.printf("Gemini API error %d: %s%n",
                        response.statusCode(), response.body());
                return FALLBACK_MESSAGE;
            }

            return extractReply(response.body());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            System.err.println("Gemini interrumpido: " + e.getMessage());
            return FALLBACK_MESSAGE;
        } catch (IOException e) {
            System.err.println("Error al conectarse con Gemini: " + e.getMessage());
            return FALLBACK_MESSAGE;
        } catch (Exception e) {
            System.err.println("Error inesperado al procesar respuesta de Gemini: " + e.getMessage());
            return FALLBACK_MESSAGE;
        }
    }

    private JsonObject buildPayload(String prompt,
                                    List<Map<String, Object>> history,
                                    int currentUserId) {
        JsonArray contents = new JsonArray();

        contents.add(content("user",
                "Eres CIA Bot, un asistente virtual amigable y servicial para una app de delivery. "
                        + "Ayuda con pedidos, dudas de la app y conversa de manera cordial y breve."));
        contents.add(content("model", "Entendido, listo para ayudar."));

        if (history != null && !history.isEmpty()) {
            int start = Math.max(0, history.size() - 12);
            for (int i = start; i < history.size(); i++) {
                Map<String, Object> message = history.get(i);
                if (message == null) {
                    continue;
                }
                Object textObj = message.get("mensaje");
                if (textObj == null) {
                    continue;
                }
                String text = textObj.toString();
                if (text.isBlank()) {
                    continue;
                }
                int senderId = -1;
                Object senderObj = message.get("id_remitente");
                if (senderObj instanceof Number number) {
                    senderId = number.intValue();
                }
                String role = (senderId == currentUserId) ? "user" : "model";
                contents.add(content(role, text));
            }
        }

        contents.add(content("user", prompt));

        JsonObject request = new JsonObject();
        request.add("contents", contents);
        return request;
    }

    private JsonObject content(String role, String text) {
        JsonObject content = new JsonObject();
        content.addProperty("role", role);
        JsonArray parts = new JsonArray();
        JsonObject part = new JsonObject();
        part.addProperty("text", text);
        parts.add(part);
        content.add("parts", parts);
        return content;
    }

    private String extractReply(String body) {
        JsonObject json = GSON.fromJson(body, JsonObject.class);
        JsonArray candidates = json != null ? json.getAsJsonArray("candidates") : null;
        if (candidates == null || candidates.isEmpty()) {
            return FALLBACK_MESSAGE;
        }

        JsonObject candidate = candidates.get(0).getAsJsonObject();
        JsonObject content = candidate.getAsJsonObject("content");
        if (content == null) {
            return FALLBACK_MESSAGE;
        }

        JsonArray parts = content.getAsJsonArray("parts");
        if (parts == null) {
            return FALLBACK_MESSAGE;
        }

        List<String> fragments = new ArrayList<>();
        for (JsonElement partEl : parts) {
            if (!partEl.isJsonObject()) {
                continue;
            }
            JsonObject part = partEl.getAsJsonObject();
            JsonElement textEl = part.get("text");
            if (textEl != null && !textEl.isJsonNull()) {
                String fragment = textEl.getAsString();
                if (!fragment.isBlank()) {
                    fragments.add(fragment.trim());
                }
            }
        }

        if (fragments.isEmpty()) {
            return FALLBACK_MESSAGE;
        }
        return String.join("\n", fragments);
    }

    private String resolveApiKey() {
        String key = System.getenv("GEMINI_API_KEY");
        if (key != null && !key.isBlank()) {
            return key.trim();
        }
        key = System.getProperty("GEMINI_API_KEY");
        if (key != null && !key.isBlank()) {
            return key.trim();
        }
        try {
            Dotenv dotenv = Dotenv.configure()
                    .directory("../delivery-api")
                    .ignoreIfMalformed()
                    .ignoreIfMissing()
                    .load();
            key = dotenv.get("GEMINI_API_KEY");
            if (key != null && !key.isBlank()) {
                return key.trim();
            }
        } catch (Exception ignored) {
        }
        return null;
    }

    private String resolveModelName() {
        String model = System.getenv("GEMINI_MODEL");
        if (model != null && !model.isBlank()) {
            return model.trim();
        }
        model = System.getProperty("GEMINI_MODEL");
        if (model != null && !model.isBlank()) {
            return model.trim();
        }
        try {
            Dotenv dotenv = Dotenv.configure()
                    .directory("../delivery-api")
                    .ignoreIfMalformed()
                    .ignoreIfMissing()
                    .load();
            model = dotenv.get("GEMINI_MODEL");
            if (model != null && !model.isBlank()) {
                return model.trim();
            }
        } catch (Exception ignored) {
        }
        return DEFAULT_MODEL_NAME;
    }
}
