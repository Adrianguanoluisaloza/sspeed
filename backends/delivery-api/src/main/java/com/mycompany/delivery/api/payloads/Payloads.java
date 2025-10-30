package com.mycompany.delivery.api.payloads;

import com.google.gson.annotations.SerializedName;
import java.util.List;

/**
 * Clases de soporte para la API Delivery (compatibles con snake_case y
 * camelCase). Acepta alias en campos críticos (id_usuario/idUsuario,
 * puntuacion/rating, etc.)
 */
public class Payloads {

    // =========================== LOGIN ===========================
    public static class LoginRequest {
        @SerializedName("correo")
        private String correo;
        @SerializedName("email")
        private String email;
        @SerializedName("contrasena")
        private String contrasena;
        @SerializedName("password")
        private String password;

        public String getCorreo() {
            return correo != null ? correo : email;
        }

        public String getContrasena() {
            return contrasena != null ? contrasena : password;
        }
    }

    // =========================== REGISTRO ===========================
    public static class RegistroRequest {
        public String nombre;
        public String correo;
        public String contrasena;
        public String telefono;
        public String rol;
    }

    // =========================== PRODUCTOS ===========================
    public static class ProductoPayload {
        public String nombre;
        public String descripcion;
        public Double precio;

        // Acepta imagen_url (snake) y imageUrl (camel) por si acaso
        @SerializedName("imagen_url")
        private String imagenUrlSnake;
        @SerializedName("imageUrl")
        private String imagenUrlCamel;

        public String categoria;
        public Boolean disponible;

        public String getImagenUrl() {
            return imagenUrlSnake != null ? imagenUrlSnake : imagenUrlCamel;
        }
    }

    // =========================== DETALLES DE PEDIDO ===========================
    public static class PedidoDetallePayload {
        @SerializedName("id_producto")
        public int idProducto;
        public int cantidad;
        public double subtotal;

        @SerializedName("precio_unitario")
        public double precioUnitario;
    }

    // =========================== PEDIDO COMPLETO ===========================
    public static class PedidoPayload {

        @SerializedName("id_cliente")
        public int idCliente;

        @SerializedName("id_delivery")
        public Integer idDelivery;

        @SerializedName("id_ubicacion")
        public Integer idUbicacion; // ✅ agregado

        // Acepta direccion_entrega y direccionEntrega
        @SerializedName("direccion_entrega")
        private String direccionEntregaSnake;
        @SerializedName("direccionEntrega")
        private String direccionEntregaCamel;

        @SerializedName("metodo_pago")
        public String metodoPago;

        public String estado;

        // ✅ Acepta "total" o "monto_total"
        @SerializedName(value = "total", alternate = { "monto_total" })
        public Double total;

        public List<PedidoDetallePayload> productos;

        // ========== Getters útiles ==========

        public String getDireccionEntrega() {
            return direccionEntregaSnake != null ? direccionEntregaSnake : direccionEntregaCamel;
        }

        public Double getTotal() {
            return total != null ? total : 0.0;
        }

        public Integer getIdUbicacion() {
            return idUbicacion; // Devuelve null si no está presente
        }
    }

    // =========================== ACTUALIZAR ESTADO ===========================
    public static class EstadoUpdateRequest {
        public String estado;
    }

    // =========================== ASIGNAR DELIVERY ===========================
    public static class AsignarPedidoRequest {
        @SerializedName("id_delivery")
        public Integer idDelivery;
    }

    // =========================== MENSAJES ===========================
    public static class MensajePayload {
        // Acepta id_remitente y idRemitente
        @SerializedName("id_remitente")
        private Integer idRemitenteSnake;
        @SerializedName("idRemitente")
        private Integer idRemitenteCamel;

        public String mensaje;

        public Integer getIdRemitente() {
            return idRemitenteSnake != null ? idRemitenteSnake : idRemitenteCamel;
        }
    }

    // =========================== TRACKING ===========================
    public static class TrackingPayload {
        public Double latitud;
        public Double longitud;
    }

    // =========================== UBICACIÓN ===========================
    public static class UbicacionRequest {
        // Acepta id_usuario y idUsuario
        @SerializedName("id_usuario")
        private Integer idUsuarioSnake;
        @SerializedName("idUsuario")
        private Integer idUsuarioCamel;

        private Double latitud;
        private Double longitud;

        // Acepta direccion (snake) y direccionEntrega (camel) por si algún cliente lo
        // manda así
        @SerializedName("direccion")
        private String direccionSnake;
        @SerializedName("direccionEntrega")
        private String direccionCamel;

        private String descripcion;
        private Boolean activa = Boolean.TRUE;

        public Integer getIdUsuario() {
            return idUsuarioSnake != null ? idUsuarioSnake : idUsuarioCamel;
        }

        public Double getLatitud() {
            return latitud;
        }

        public Double getLongitud() {
            return longitud;
        }

        public String getDireccion() {
            return direccionSnake != null ? direccionSnake : direccionCamel;
        }

        public String getDescripcion() {
            return descripcion;
        }

        public Boolean getActiva() {
            return activa;
        }
    }

    // =========================== RECOMENDACIONES ===========================
    public static class RecomendacionPayload {
        // Acepta id_usuario y idUsuario
        @SerializedName("id_usuario")
        private Integer idUsuarioSnake;
        @SerializedName("idUsuario")
        private Integer idUsuarioCamel;

        // Acepta puntuacion y rating
        @SerializedName("puntuacion")
        private Integer puntuacion;
        @SerializedName("rating")
        private Integer rating;

        public String comentario;

        public Integer getIdUsuario() {
            return idUsuarioSnake != null ? idUsuarioSnake : idUsuarioCamel;
        }

        public Integer getPuntuacion() {
            return puntuacion != null ? puntuacion : rating;
        }
    }

    // =========================== CHAT ===========================
    public static class ChatMensajePayload {
        @SerializedName("idConversacion")
        public Long idConversacion;
        @SerializedName("idRemitente")
        public Integer idRemitente;
        @SerializedName("idDestinatario")
        public Integer idDestinatario;
        @SerializedName("idPedido")
        public Integer idPedido;
        @SerializedName("idCliente")
        public Integer idCliente;
        @SerializedName("idDelivery")
        public Integer idDelivery;
        public String mensaje;
    }

    // =========================== CHAT BOT ===========================
    public static class ChatBotRequest {
        @SerializedName("idRemitente")
        public Integer idRemitente;

        @SerializedName("idConversacion")
        public Long idConversacion; // Puede ser nulo si es una nueva conversación

        public String mensaje;
    }

    /**
     * Payload para solicitar las ubicaciones de múltiples repartidores. Contiene
     * una lista de IDs de repartidores.
     */
    public static class UbicacionesRequest {
        public List<Integer> ids;
    }
}
