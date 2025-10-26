
package com.mycompany.delivery.api.util;


import com.google.gson.annotations.SerializedName;

/**
 * ✅ Respuesta estandarizada para todas las operaciones HTTP.
 * Garantiza compatibilidad con Flutter sin tener que hacer parsing condicional.
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
        return new ApiResponse<>(status, false, message, null, errorDetails);
    }

    public static ApiResponse<Void> error(int status, String message) {
        return error(status, message, null);
    }

    public int getStatus() { return status; }
    public boolean isSuccess() { return success; }
    public String getMessage() { return message; }
    public T getData() { return data; }
    public Object getErrorDetails() { return errorDetails; }
}

//----------------------------------------------------------

