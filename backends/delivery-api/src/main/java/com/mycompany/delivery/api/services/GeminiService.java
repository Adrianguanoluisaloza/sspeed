package com.mycompany.delivery.api.services;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import com.google.gson.Gson;

public class GeminiService {

    private static final String API_KEY = System.getenv("GEMINI_API_KEY");
    private static final String API_URL = "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash-latest:generateContent";
    private final HttpClient httpClient;
    private final Gson gson;

    public GeminiService() {
        this.httpClient = HttpClient.newBuilder().version(HttpClient.Version.HTTP_2)
                .connectTimeout(Duration.ofSeconds(10)).build();
        this.gson = new Gson();
    }

    public String generateReply(String prompt, List<Map<String, Object>> history, int currentUserId) {
        if (API_KEY == null || API_KEY.isBlank()) {
            System.err.println("[ERROR] La variable de entorno GEMINI_API_KEY no está configurada.");
            return "Lo siento, mi cerebro (IA) no está disponible en este momento. Por favor, contacta a soporte.";
        }

        List<Map<String, Object>> contents = new ArrayList<>();
        // System Prompt
        contents.add(Map.of("role", "user", "parts", List.of(Map.of("text",
                "Eres CIA Bot, un asistente virtual amigable y servicial para una app de delivery de comida. Tu objetivo es ayudar a los usuarios con sus dudas sobre pedidos, la app, o simplemente conversar de forma amena. Sé breve y directo."))));
        contents.add(Map.of("role", "model", "parts", List.of(Map.of("text", "¡Entendido! Estoy listo para ayudar."))));

        // History
        for (Map<String, Object> msg : history) {
            Object remitenteObj = msg.get("id_remitente");
            if (remitenteObj instanceof Number num) {
                int idRemitente = num.intValue();
                String role = (idRemitente == currentUserId) ? "user" : "model";
                contents.add(Map.of("role", role, "parts", List.of(Map.of("text", msg.get("mensaje")))));
            }
        }

        // Current prompt
        contents.add(Map.of("role", "user", "parts", List.of(Map.of("text", prompt))));

        Map<String, Object> payload = Map.of("contents", contents);
        String requestBody = gson.toJson(payload);

        HttpRequest request = HttpRequest.newBuilder().uri(URI.create(API_URL + "?key=" + API_KEY))
                .header("Content-Type", "application/json").POST(HttpRequest.BodyPublishers.ofString(requestBody))
                .build();

        try {
            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() == 200) {
                return parseResponse(response.body());
            } else {
                System.err.println("Error en la API de Gemini: " + response.statusCode() + " - " + response.body());
                return "Tuve un problema para procesar tu solicitud. Inténtalo de nuevo.";
            }
        } catch (IOException | InterruptedException e) {
            System.err.println("Excepción al llamar a la API de Gemini: " + e.getMessage());
            Thread.currentThread().interrupt();
            return "No pude conectarme para generar una respuesta. Revisa tu conexión.";
        }
    }

    private String parseResponse(String jsonBody) {
        try {
            Map<?, ?> responseMap = gson.fromJson(jsonBody, Map.class);
            Object candidatesObj = responseMap.get("candidates");
            if (candidatesObj instanceof List<?> candidates && !candidates.isEmpty()) {
                Object firstCandidateObj = candidates.get(0);
                if (firstCandidateObj instanceof Map<?, ?> firstCandidate) {
                    Object contentObj = firstCandidate.get("content");
                    if (contentObj instanceof Map<?, ?> content) {
                        Object partsObj = content.get("parts");
                        if (partsObj instanceof List<?> parts && !parts.isEmpty()) {
                            Object firstPartObj = parts.get(0);
                            if (firstPartObj instanceof Map<?, ?> firstPart) {
                                Object textObj = firstPart.get("text");
                                if (textObj instanceof String text) {
                                    return text;
                                }
                            }
                        }
                    }
                }
            }
        } catch (IllegalStateException e) {
            System.err.println("Error al parsear la respuesta de Gemini: " + e.getMessage());
        }
        return "No entendí la respuesta. ¿Podrías preguntar de otra forma?";
    }
}