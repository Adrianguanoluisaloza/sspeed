package com.mycompany.delivery.api.services;

import com.mycompany.delivery.api.repository.RespuestaSoporteRepository;
import com.mycompany.delivery.api.model.RespuestaSoporte;

import java.util.Map;
import java.util.Optional;

public class SoporteBotService {

    private final RespuestaSoporteRepository repo = new RespuestaSoporteRepository();

    /**
     * Procesa un mensaje de usuario y obtiene la mejor respuesta disponible.
     * 1. Coincidencia por categoría
     * 2. Si no existe categoría, intenta similitud de texto
     * 3. Si no encuentra nada → devuelve empty() para activar IA o humano
     */
    public Optional<String> obtenerRespuesta(String mensajeUsuario, String categoria, Map<String, Object> data) {

        // 1. Buscar por categoría exacta
        Optional<RespuestaSoporte> catMatch = repo.buscarPorCategoria(categoria);
        if (catMatch.isPresent()) {
            return Optional.of(reemplazarVariables(catMatch.get().getMensaje(), data));
        }

        // 2. Buscar por similitud de texto
        Optional<RespuestaSoporte> simMatch = repo.buscarPorTextoCercano(mensajeUsuario);
        if (simMatch.isPresent()) {
            return Optional.of(reemplazarVariables(simMatch.get().getMensaje(), data));
        }

        return Optional.empty(); // Activa IA o espera humano
    }

    private String reemplazarVariables(String mensaje, Map<String, Object> data) {
        return mensaje
                .replace("{usuario}", String.valueOf(data.getOrDefault("usuario", "")))
                .replace("{pedido}", String.valueOf(data.getOrDefault("pedido", "")))
                .replace("{negocio}", String.valueOf(data.getOrDefault("negocio", "")))
                .replace("{delivery}", String.valueOf(data.getOrDefault("delivery", "")));
    }
}
