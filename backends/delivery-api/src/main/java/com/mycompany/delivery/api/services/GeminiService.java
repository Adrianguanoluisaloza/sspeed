package com.mycompany.delivery.api.services;

import chat.dim.protocol.Content;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

// *** CAMBIOS DE IMPORTACIÓN ***
import com.google.ai.client.generativeai.GenerativeModel;
import com.google.ai.client.generativeai.java.ChatFutures; // Para chat
import com.google.ai.client.generativeai.type.Content;
import com.google.ai.client.generativeai.type.GenerateContentResponse;
import com.google.ai.client.generativeai.type.Part;
import com.google.ai.client.generativeai.type.ClientException; // SDK correcto

import io.github.cdimascio.dotenv.Dotenv;
import jakarta.servlet.http.Part;
import java.util.concurrent.ExecutionException; // Necesario para la llamada

/**
 * Servicio de integración con la API de Gemini utilizando el SDK oficial
 * {@code com.google.ai.client.generativeai}.
 */
public class GeminiService implements AutoCloseable { // No necesita AutoCloseable

    private static final String DEFAULT_MODEL_NAME = "gemini-1.5-flash-001";
    private static final String FALLBACK_MESSAGE =
            "Lo siento, mi cerebro (IA) no está disponible en este momento. Por favor, contacta a soporte.";

    // *** CAMBIO: El modelo se instancia con el nombre y la API key ***
    private final GenerativeModel model;
    private final String apiKey; // Guardamos la key

    public GeminiService() {
        this.apiKey = resolveApiKey();
        if (this.apiKey == null || this.apiKey.isBlank()) {
            System.err.println("[ERROR] La variable de entorno GEMINI_API_KEY no está configurada.");
            this.model = null; // No se puede inicializar
        } else {
            // Inicializa el modelo (pero el chat se maneja de otra forma)
            // Dejamos model nulo por ahora y lo creamos por solicitud
             this.model = null; // Ver nota abajo
        }
    }
    
    // ... (Tu método resolveApiKey() se queda igual) ...
    private String resolveApiKey() {
        // ... tu código existente está bien ...
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
        if (apiKey == null) { // Comprueba si la API key se cargó
            return FALLBACK_MESSAGE;
        }

        List<Content> historyContents = new ArrayList<>();

        // Mensaje de contexto para mantener el rol del asistente.
        historyContents.add(buildContent("user",
                "Eres CIA Bot, un asistente virtual amigable y servicial para una app de delivery de comida. "
                        + "Tu objetivo es ayudar a los usuarios con sus dudas sobre pedidos, la app, o simplemente "
                        + "conversar de forma amena. Sé breve y directo."));
        historyContents.add(buildContent("model", "Entendido. Estoy listo para ayudar."));

        // Historial de conversación.
        if (history != null) {
            for (Map<String, Object> msg : history) {
                // ... (Tu lógica de historial está bien) ...
                if (msg == null) continue;
                Object remitenteObj = msg.get("id_remitente");
                Object mensajeObj = msg.get("mensaje");
                if (mensajeObj == null) continue;
                int idRemitente = remitenteObj instanceof Number ? ((Number) remitenteObj).intValue() : -1;
                String role = (idRemitente == currentUserId) ? "user" : "model";
                String texto = mensajeObj.toString();
                if (texto != null && !texto.isBlank()) {
                    historyContents.add(buildContent(role, texto));
                }
            }
        }
        
        // *** CAMBIO: El SDK maneja el historial y el prompt de forma diferente ***
        // El SDK oficial de Java maneja el chat con un objeto "ChatFutures"
        
        try {
            String modelName = resolveModelName();
            
            // 1. Crea la instancia del modelo AQUÍ
            GenerativeModel chatModel = new GenerativeModel(modelName, apiKey);
            
            // 2. Inicia una sesión de chat y le pasas el historial
            ChatFutures chat = chatModel.startChat(historyContents);

            // 3. Envía el nuevo mensaje (prompt)
            String safePrompt = prompt == null ? "" : prompt;
            
            // El SDK nuevo es asíncrono, usamos .get() para esperar la respuesta
            GenerateContentResponse response = chat.sendMessage(safePrompt).get(); 

            // 4. Obtiene el texto de la respuesta
            String reply = response.getText();
            
            if (reply == null || reply.isBlank()) {
                return "No entendí la respuesta. ¿Podrías preguntar de otra forma?";
            }
            return reply;
            
        } catch (ClientException e) {
            System.err.println("Error en la API de Gemini: " + e.getMessage());
            // Este es el error que estabas viendo (404)
            return "Tuve un problema para procesar tu solicitud. Inténtalo de nuevo.";
        } catch (ExecutionException | InterruptedException e) {
             System.err.println("Error en la llamada asíncrona de Gemini: " + e.getMessage());
            return "No pude conectarme para generar una respuesta. Revisa tu conexión.";
        } catch (Exception e) {
            System.err.println("Excepción inesperada al llamar a la API de Gemini: " + e.getMessage());
            return "No pude conectarme para generar una respuesta. Revisa tu conexión.";
        }
    }

    // ... (Tu método buildContent() se queda igual) ...
    private Content buildContent(String role, String text) {
        return Content.builder()
                .role(role)
                .parts(List.of(Part.fromText(text)))
                .build();
    }
    
    // ... (Tu método resolveModelName() se queda igual) ...
    private String resolveModelName() {
         // ... tu código existente está bien ...
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
        // El nuevo SDK no requiere un .close()
    }
}