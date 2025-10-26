package com.mycompany.delivery.api.util;

import com.google.gson.annotations.SerializedName;

/**
 * Respuesta estándar para la API para que Flutter reciba siempre el mismo formato.
 * Mantener un contrato único reduce errores de parsing y facilita el manejo de estados.
 */
public final class ApiResponse<T> {

    private final int status;
    private final boolean success;
    private final String message;
    private final T data;
    @SerializedName("errors")
    private final Object errorDetails;

    private ApiResponse(int status, boolean success, String message, T data, Object errorDetails) {
        this.status = status;
        this.success = success;
        this.message = message;
        this.data = data;
        this.errorDetails = errorDetails;
    }

    public static <T> ApiResponse<T> success(int status, String message, T data) {
        // Centralizamos la construcción exitosa para evitar códigos incongruentes en cada handler.
        return new ApiResponse<>(status, true, message, data, null);
    }

    public static <T> ApiResponse<T> success(String message, T data) {
        return success(200, message, data);
    }

    public static ApiResponse<Void> success(String message) {
        return success(200, message, null);
    }

    public static ApiResponse<Void> created(String message) {
        return success(201, message, null);
    }

    public static <T> ApiResponse<T> error(int status, String message, Object errorDetails) {
        // El detalle adicional permite enviar pistas al frontend sin exponer internals sensibles.
        return new ApiResponse<>(status, false, message, null, errorDetails);
    }

    public static ApiResponse<Void> error(int status, String message) {
        return error(status, message, null);
    }

    public int getStatus() {
        return status;
    }

    public boolean isSuccess() {
        return success;
    }

    public String getMessage() {
        return message;
    }

    public T getData() {
        return data;
    }

    public Object getErrorDetails() {
        return errorDetails;
    }
}
