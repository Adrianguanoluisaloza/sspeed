package com.mycompany.delivery.api.util;

/**
 * Excepción controlada para notificar errores a la capa HTTP sin perder el stack trace.
 * Usamos RuntimeException para simplificar propagación en lambdas Spark.
 */
public class ApiException extends RuntimeException {

    private final int status;
    private final transient Object details;

    public ApiException(int status, String message) {
        super(message);
        this.status = status;
        this.details = null;
    }

    public ApiException(int status, String message, Throwable cause) {
        super(message, cause);
        this.status = status;
        this.details = null;
    }

    public ApiException(int status, String message, Object details) {
        super(message);
        this.status = status;
        this.details = details;
    }

    public int getStatus() {
        return status;
    }

    public Object getDetails() {
        return details;
    }
}
