// Dependencia para cargar variables de entorno desde .env
// Agrega esto en tu pom.xml:
//
// <dependency>
//   <groupId>io.github.cdimascio</groupId>
//   <artifactId>dotenv-java</artifactId>
//   <version>3.0.0</version>
// </dependency>
//
// Ejemplo de uso en tu backend:
// import io.github.cdimascio.dotenv.Dotenv;
// Dotenv dotenv = Dotenv.load();
// String geminiKey = dotenv.get("GEMINI_API_KEY");
// String mapsKey = dotenv.get("GOOGLE_MAPS_API_KEY");
//
// Así puedes usar las claves aunque no estén en el entorno del sistema.
