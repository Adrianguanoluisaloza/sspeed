/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.mycompany.delivery.api.config;
import org.mindrot.jbcrypt.BCrypt;

public class GenerateHash {
    public static void main(String[] args) {
        // ----> Pon aquí la contraseña que quieres usar <----
        String passwordToHash = "123456"; 

        String hashedPassword = BCrypt.hashpw(passwordToHash, BCrypt.gensalt());

        System.out.println("Tu contraseña en texto plano es: " + passwordToHash);
        System.out.println("Copia y pega este HASH en tu base de datos:");
        System.out.println(hashedPassword);
    }
}
