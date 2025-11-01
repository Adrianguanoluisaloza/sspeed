package com.mycompany.delivery.api.controller;

import com.mycompany.delivery.api.model.Negocio;
import com.mycompany.delivery.api.model.Usuario;
import com.mycompany.delivery.api.repository.NegocioRepository;
import com.mycompany.delivery.api.repository.UsuarioRepository;
import com.mycompany.delivery.api.util.ApiException;
import com.mycompany.delivery.api.util.ApiResponse;

import java.sql.SQLException;
import java.util.List;
import java.util.Optional;

/**
 * Controlador para el registro y consulta de negocios asociados a usuarios.
 */
public class NegocioController {

    private final NegocioRepository negocioRepo = new NegocioRepository();
    private final UsuarioRepository usuarioRepo = new UsuarioRepository();

    public ApiResponse<Negocio> obtenerPorUsuario(int idUsuario) {
        if (idUsuario <= 0) {
            throw new ApiException(400, "Identificador de usuario invalido");
        }
        try {
            Optional<Negocio> negocio = negocioRepo.findByUsuario(idUsuario);
            return ApiResponse.success(200, "Negocio obtenido",
                    negocio.orElse(null));
        } catch (SQLException e) {
            throw new ApiException(500, "Error al obtener negocio", e);
        }
    }

    public ApiResponse<Negocio> registrarONActualizar(int idUsuario, Negocio payload) {
        if (idUsuario <= 0) {
            throw new ApiException(400, "Identificador de usuario invalido");
        }
        validarNegocio(payload);
        try {
            Usuario usuario = usuarioRepo.obtenerPorId(idUsuario)
                    .orElseThrow(() -> new ApiException(404, "Usuario no encontrado"));
            if (!usuario.isActivo()) {
                throw new ApiException(403, "El usuario esta inactivo");
            }

            // Asegura que el RUC sea unico (permitiendo el mismo registro)
            Optional<Negocio> rucExistente = negocioRepo.findByRuc(payload.getRuc());
            if (rucExistente.isPresent() && rucExistente.get().getIdUsuario() != idUsuario) {
                throw new ApiException(409, "El RUC ya esta registrado para otro negocio");
            }

            Optional<Negocio> existente = negocioRepo.findByUsuario(idUsuario);
            if (existente.isPresent()) {
                Negocio negocio = existente.get();
                negocio.setNombreComercial(payload.getNombreComercial());
                negocio.setRuc(payload.getRuc());
                negocio.setDireccion(payload.getDireccion());
                negocio.setTelefono(payload.getTelefono());
                negocio.setLogoUrl(payload.getLogoUrl());
                negocio.setActivo(true);
                negocioRepo.update(negocio);
                return ApiResponse.success(200, "Negocio actualizado correctamente", negocio);
            } else {
                payload.setIdUsuario(idUsuario);
                Negocio creado = negocioRepo.create(payload);
                return ApiResponse.success(201, "Negocio registrado correctamente", creado);
            }
        } catch (SQLException e) {
            throw new ApiException(500, "Error al registrar el negocio", e);
        }
    }

    public ApiResponse<List<Negocio>> listarNegocios() {
        try {
            return ApiResponse.success(200, "Negocios listados", negocioRepo.findAll());
        } catch (SQLException e) {
            throw new ApiException(500, "Error al listar negocios", e);
        }
    }

    public ApiResponse<Negocio> obtenerPorId(int idNegocio) {
        if (idNegocio <= 0) {
            throw new ApiException(400, "Identificador de negocio invalido");
        }
        try {
            Optional<Negocio> negocio = negocioRepo.findById(idNegocio);
            if (negocio.isEmpty()) {
                throw new ApiException(404, "Negocio no encontrado");
            }
            return ApiResponse.success(200, "Negocio encontrado", negocio.get());
        } catch (SQLException e) {
            throw new ApiException(500, "Error al obtener negocio", e);
        }
    }

    public ApiResponse<Negocio> actualizar(int idNegocio, Negocio payload) {
        if (idNegocio <= 0) {
            throw new ApiException(400, "Identificador de negocio invalido");
        }
        validarNegocio(payload);
        try {
            Negocio existente = negocioRepo.findById(idNegocio)
                    .orElseThrow(() -> new ApiException(404, "Negocio no encontrado"));

            // Evitar duplicidad de RUC
            Optional<Negocio> rucExistente = negocioRepo.findByRuc(payload.getRuc());
            if (rucExistente.isPresent() && rucExistente.get().getIdNegocio() != idNegocio) {
                throw new ApiException(409, "El RUC ya esta registrado para otro negocio");
            }

            existente.setNombreComercial(payload.getNombreComercial());
            existente.setRuc(payload.getRuc());
            existente.setDireccion(payload.getDireccion());
            existente.setTelefono(payload.getTelefono());
            existente.setLogoUrl(payload.getLogoUrl());
            existente.setActivo(payload.isActivo());
            negocioRepo.update(existente);
            return ApiResponse.success(200, "Negocio actualizado", existente);
        } catch (SQLException e) {
            throw new ApiException(500, "Error al actualizar negocio", e);
        }
    }

    private void validarNegocio(Negocio negocio) {
        if (negocio == null) {
            throw new ApiException(400, "Datos de negocio requeridos");
        }
        if (negocio.getNombreComercial() == null || negocio.getNombreComercial().trim().isEmpty()) {
            throw new ApiException(400, "El nombre comercial es obligatorio");
        }
        if (negocio.getRuc() == null || negocio.getRuc().trim().isEmpty()) {
            throw new ApiException(400, "El RUC es obligatorio");
        }
        String ruc = negocio.getRuc().trim();
        if (ruc.length() < 10 || ruc.length() > 13) {
            throw new ApiException(400, "El RUC debe tener entre 10 y 13 caracteres");
        }
        negocio.setNombreComercial(negocio.getNombreComercial().trim());
        negocio.setRuc(ruc);
        if (negocio.getDireccion() != null) {
            negocio.setDireccion(negocio.getDireccion().trim());
        }
        if (negocio.getTelefono() != null) {
            negocio.setTelefono(negocio.getTelefono().trim());
        }
        if (negocio.getLogoUrl() != null) {
            negocio.setLogoUrl(negocio.getLogoUrl().trim());
        }
    }
}
