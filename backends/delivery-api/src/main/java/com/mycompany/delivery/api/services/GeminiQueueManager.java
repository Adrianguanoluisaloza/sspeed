package com.mycompany.delivery.api.services;

import java.util.LinkedList;
import java.util.List;
import java.util.Queue;

public class GeminiQueueManager {

    private static final long COOLDOWN_MS = 60_000; // 1 min (free tier)
    private long lastCallTimestamp = 0;

    private final Queue<PendingMessage> queue = new LinkedList<>();
    private final GeminiService gemini;

    public GeminiQueueManager(GeminiService gemini) {
        this.gemini = gemini;
    }

    public synchronized String handleMessage(int idConversacion, String prompt) {
        long now = System.currentTimeMillis();

        if (now - lastCallTimestamp < COOLDOWN_MS) {
            queue.add(new PendingMessage(idConversacion, prompt));
            return "🤖 Estoy pensando... dame unos segundos...";
        }

        lastCallTimestamp = now;
        return gemini.generateReply(prompt, List.of(), -1);
    }

    public synchronized void processQueue() {
        if (queue.isEmpty()) return;

        long now = System.currentTimeMillis();
        if (now - lastCallTimestamp < COOLDOWN_MS) return;

        PendingMessage next = queue.poll();
        lastCallTimestamp = now;
        String reply = gemini.generateReply(next.prompt, List.of(), -1);

        System.out.printf("[Gemini] Respuesta generada para conversación %d: %s%n",
                next.idConversacion, reply);
        // Aquí deberás guardar respuesta en DB: INSERT chat_mensajes ...
    }

    private static class PendingMessage {
        int idConversacion;
        String prompt;
        public PendingMessage(int idConversacion, String prompt) {
            this.idConversacion = idConversacion;
            this.prompt = prompt;
        }
    }
}
