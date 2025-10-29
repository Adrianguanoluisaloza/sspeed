package com.mycompany.delivery.api.controller;

import java.sql.SQLException;
import java.util.List;
import java.util.Optional;

import com.mycompany.delivery.api.model.Usuario;
import com.mycompany.delivery.api.repository.UsuarioRepository;
import com.mycompany.delivery.api.util.ApiException;
import com.mycompany.delivery.api.util.ApiResponse;

/**
 * Controlador REST para la gestión de usuarios.
 * Contiene autenticación, registro, edición, listado y eliminación.
 */
public class UsuarioController {

    private final UsuarioRepository repo = new UsuarioRepository();

        /**
         * Valida el token JWT y devuelve el usuario autenticado.
         * Simulación: decodifica el token y busca el usuario por id.
         * Reemplaza por tu lógica real de validación JWT.
         */
        public Usuario validarToken(String token) {
            // Simulación: el token es el id_usuario en texto
            try {
                int idUsuario = Integer.parseInt(token); // Reemplaza por decodificación JWT real
                Optional<Usuario> usuarioOpt = repo.obtenerPorId(idUsuario);
                if (usuarioOpt.isEmpty()) {
                    throw new ApiException(401, "Usuario no encontrado para el token");
                }
                Usuario usuario = usuarioOpt.get();
                if (!usuario.isActivo()) {
                    throw new ApiException(403, "El usuario asociado a este token ha sido desactivado.");
                }
                if (!usuario.isActivo()) {
                    throw new ApiException(403, "Usuario inactivo");
                }
                if (usuario.getRol() == null || usuario.getRol().isBlank()) {
                    throw new ApiException(403, "Usuario sin rol definido");
                }
                return usuario;
            } catch (NumberFormatException e) {
                throw new ApiException(401, "Token inválido");
            } catch (ApiException e) {
                throw e;
            } catch (SQLException e) {
                throw new ApiException(500, "Error de base de datos al validar token", e);
            }
        }
    // ===========================
    // LOGIN
    // ===========================
    public ApiResponse<java.util.Map<String, Object>> login(String correo, String contrasena) {
        if (correo == null || correo.isBlank() || contrasena == null || contrasena.isBlank()) {
            throw new ApiException(400, "Correo y contraseña son obligatorios");
        }
        try {
            Optional<Usuario> usuarioOpt = repo.autenticar(correo, contrasena);
            if (usuarioOpt.isEmpty()) {
                throw new ApiException(401, "Credenciales incorrectas");
            }
            Usuario usuario = usuarioOpt.get();
            // El token es el idUsuario. Se añade al mapa del usuario.
            java.util.Map<String, Object> userMap = usuario.toMap();
            userMap.put("token", String.valueOf(usuario.getIdUsuario())); // Simulación JWT
            return ApiResponse.success(200, "Inicio de sesión exitoso", userMap);
        } catch (SQLException e) {
            throw new ApiException(500, "Error al autenticar usuario", e);
        }
    }

    // ===========================
    // REGISTRO
    // ===========================
    public ApiResponse<Void> registrar(Usuario usuario) {
        if (usuario == null) throw new ApiException(400, "Datos del usuario requeridos");
        if (usuario.getCorreo() == null || usuario.getCorreo().isBlank()) {
            throw new ApiException(400, "El correo es obligatorio");
        }
        if (usuario.getContrasena() == null || usuario.getContrasena().isBlank()) {
            throw new ApiException(400, "La contraseña es obligatoria");
        }
        try {
            boolean creado = repo.registrar(usuario);
            if (!creado) throw new ApiException(500, "No se pudo registrar el usuario");
            return ApiResponse.created("Usuario registrado correctamente");
        } catch (SQLException e) {
            if (e.getMessage().contains("duplicate key")) {
                throw new ApiException(409, "El correo ya está registrado", e);
            }
            throw new ApiException(500, "Error interno al registrar el usuario", e);
        }
    }

    // ===========================
    // LISTAR USUARIOS
    // ===========================
    public ApiResponse<List<Usuario>> listarUsuarios() {
        try {
            List<Usuario> lista = repo.listarUsuarios();
            return ApiResponse.success(200, "Usuarios listados correctamente", lista);
        } catch (SQLException e) {
            throw new ApiException(500, "No se pudieron listar los usuarios", e);
        }
    }

    // ===========================
    // OBTENER POR ID
    // ===========================
    public ApiResponse<Usuario> obtenerPorId(int idUsuario) {
        if (idUsuario <= 0) throw new ApiException(400, "ID de usuario inválido");
        try {
            Optional<Usuario> usuario = repo.obtenerPorId(idUsuario);
            if (usuario.isEmpty()) throw new ApiException(404, "Usuario no encontrado");
            return ApiResponse.success(200, "Usuario encontrado", usuario.get());
        } catch (SQLException e) {
            throw new ApiException(500, "Error al obtener el usuario", e);
        }
    }

    // ===========================
    // ACTUALIZAR DATOS
    // ===========================
    public ApiResponse<Void> actualizarUsuario(Usuario usuario) {
        if (usuario == null || usuario.getIdUsuario() <= 0) {
            throw new ApiException(400, "Datos de usuario inválidos");
        }
        try {
            boolean actualizado = repo.actualizar(usuario);
            if (!actualizado) throw new ApiException(404, "Usuario no encontrado para actualizar");
            return ApiResponse.success("Usuario actualizado correctamente");
        } catch (SQLException e) {
            throw new ApiException(500, "Error actualizando usuario", e);
        }
    }

    // ===========================
    // ELIMINAR USUARIO
    // ===========================
    public ApiResponse<Void> eliminarUsuario(int idUsuario) {
        if (idUsuario <= 0) throw new ApiException(400, "ID de usuario inválido");
        try {
            boolean eliminado = repo.eliminar(idUsuario);
            if (!eliminado) throw new ApiException(404, "Usuario no encontrado para eliminar");
            return ApiResponse.success("Usuario eliminado correctamente");
        } catch (SQLException e) {
            throw new ApiException(500, "Error al eliminar usuario", e);
        }
    }
}
