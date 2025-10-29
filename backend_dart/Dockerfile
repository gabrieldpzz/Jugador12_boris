# Etapa 1: Compilar la app
FROM dart:stable AS build
WORKDIR /app

COPY pubspec.* .
RUN dart pub get

COPY . .
RUN dart compile exe bin/server.dart -o server

# Etapa 2: Crear la imagen final
# --- ¡EL CAMBIO IMPORTANTE ESTÁ AQUÍ! ---
# Usamos 'debian:bookworm-slim' en lugar de 'alpine'
# para que las librerías del sistema (libc) sean compatibles.
FROM debian:bookworm-slim
WORKDIR /app

# Copiamos el ejecutable compilado de la etapa 'build'
COPY --from=build /app/server /app/server

# Damos permisos de ejecución (buena práctica)
RUN chmod +x /app/server

# Expone el puerto 8080
EXPOSE 8080

# Comando para correr el servidor
CMD ["/app/server"]