package com.mycompany.delivery.api.controller;

import com.mycompany.delivery.api.model.Usuario;
import com.mycompany.delivery.api.repository.UsuarioRepository;
import com.mycompany.delivery.api.util.ApiException;
import com.mycompany.delivery.api.util.ApiResponse;
import java.sql.SQLException;
import java.util.List;
import java.util.Optional;
import java.util.regex.Pattern;
import org.mindrot.jbcrypt.BCrypt;

/**
 * Lógica de usuarios desacoplada de Spark para facilitar pruebas y reutilización.
 */
public class UsuarioController {

    private static final Pattern EMAIL_PATTERN = Pattern.compile("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+$");
    private final UsuarioRepository repo = new UsuarioRepository();

    public ApiResponse<Usuario> login(String correo, String contrasenaPlana) {
        if (correo == null || correo.isBlank()) {
            throw new ApiException(400, "El correo es obligatorio");
        }
        if (contrasenaPlana == null || contrasenaPlana.isBlank()) {
            throw new ApiException(400, "La contraseña es obligatoria");
        }

        try {
            // Se usa una variable para el correo normalizado, es más limpio.
            String correoNormalizado = correo.trim().toLowerCase();
            Optional<Usuario> optUsuario = repo.findByCorreo(correoNormalizado);
            
            if (optUsuario.isEmpty() || !optUsuario.get().isActivo()) {
                throw new ApiException(401, "Usuario no encontrado o inactivo");
            }

            Usuario usuario = optUsuario.get();
            
            // Esta es la lógica de 'HEAD', que es mucho más segura y robusta.
            // Permite migrar contraseñas antiguas que no estaban encriptadas.
            String hashAlmacenado = usuario.getContrasena();
            if (hashAlmacenado == null || hashAlmacenado.isBlank()) {
                throw new ApiException(401, "Credenciales inválidas");
            }

            boolean requiereRehash = false;
            boolean credencialesValidas;

            if (esHashBcrypt(hashAlmacenado)) {
                try {
                    credencialesValidas = BCrypt.checkpw(contrasenaPlana, hashAlmacenado);
                } catch (IllegalArgumentException ex) {
                    // Si el hash está corrupto, hacemos un último intento comparando texto plano.
                    credencialesValidas = hashAlmacenado.equals(contrasenaPlana);
                    requiereRehash = credencialesValidas;
                }
            } else {
                // Compatibilidad con datos antiguos guardados sin hash.
                credencialesValidas = hashAlmacenado.equals(contrasenaPlana);
                requiereRehash = credencialesValidas;
            }

            if (!credencialesValidas) {
                throw new ApiException(401, "Credenciales inválidas");
            }

            // Si la contraseña era válida pero no estaba en BCrypt, se actualiza ahora.
            if (requiereRehash) {
                String nuevoHash = BCrypt.hashpw(contrasenaPlana, BCrypt.gensalt());
                try {
                    if (repo.actualizarHashContrasena(usuario.getIdUsuario(), nuevoHash)) {
                        System.out.println("🔐 Hash de contraseña migrado a BCrypt para: " + correoNormalizado);
                        usuario.setContrasena(nuevoHash);
                    }
                } catch (SQLException e) {
                    // No abortamos el login si la migración falla; solo registramos el problema.
                    System.err.println("⚠️ No se pudo actualizar el hash heredado para " + correoNormalizado + ": " + e.getMessage());
                }
            }

            usuario.setContrasena(null); // No exponemos hashes al cliente.
            System.out.println("ℹ️ Usuario " + usuario.getCorreo() + " inició sesión correctamente.");
            return ApiResponse.success("Inicio de sesión exitoso", usuario);
        } catch (SQLException e) {
            System.err.println("❌ Error consultando usuario: " + e.getMessage());
            throw new ApiException(500, "No se pudo verificar las credenciales", e);
        }
    }

    public ApiResponse<Void> registrar(Usuario nuevoUsuario) {
        validarNuevoUsuario(nuevoUsuario);

        try {
            if (repo.findByCorreo(nuevoUsuario.getCorreo()).isPresent()) {
                throw new ApiException(409, "El correo ya está registrado");
            }

            boolean creado = repo.crearUsuario(nuevoUsuario);
            if (!creado) {
                throw new ApiException(500, "No se pudo registrar el usuario");
            }

            System.out.println("ℹ️ Usuario registrado: " + nuevoUsuario.getCorreo());
            return ApiResponse.created("Registro exitoso");
        } catch (SQLException e) {
            System.err.println("❌ Error guardando usuario: " + e.getMessage());
            throw new ApiException(500, "Error al registrar el usuario", e);
        }
    }

    public ApiResponse<List<Usuario>> listarUsuarios() {
        try {
            List<Usuario> usuarios = repo.listarUsuarios();
            return ApiResponse.success(200, "Usuarios recuperados correctamente", usuarios);
        } catch (SQLException e) {
            System.err.println("❌ Error listando usuarios: " + e.getMessage());
            throw new ApiException(500, "No se pudieron obtener los usuarios", e);
        }
    }

    private void validarNuevoUsuario(Usuario usuario) {
        if (usuario == null) {
            throw new ApiException(400, "El cuerpo de la solicitud es obligatorio");
        }
        if (usuario.getNombre() == null || usuario.getNombre().isBlank()) {
            throw new ApiException(400, "El nombre es obligatorio");
        }
        if (usuario.getCorreo() == null || !EMAIL_PATTERN.matcher(usuario.getCorreo()).matches()) {
            throw new ApiException(400, "Correo inválido");
        }
        usuario.setCorreo(usuario.getCorreo().trim().toLowerCase());
        if (usuario.getContrasena() == null || usuario.getContrasena().length() < 6) {
            throw new ApiException(400, "La contraseña debe tener al menos 6 caracteres");
        }
    }

    // Se eliminó la copia duplicada de 'validarNuevoUsuario' que venía del merge.

    private boolean esHashBcrypt(String valor) {
        return valor.startsWith("$2a$") || valor.startsWith("$2b$") || valor.startsWith("$2y$");
    }
}
