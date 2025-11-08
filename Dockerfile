# Use official OpenJDK image as a parent image
FROM eclipse-temurin:17-jre-alpine

# Set working directory
WORKDIR /app

# Copy the built jar into the image
COPY target/*.jar app.jar

# Expose the application's port
EXPOSE 8080

# Run the jar file
ENTRYPOINT ["java", "-jar", "app.jar"]
