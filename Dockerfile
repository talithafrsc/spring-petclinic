# Stage 1: Build stage
FROM eclipse-temurin:21-jdk-jammy AS base

WORKDIR /app

COPY .mvn/ .mvn
COPY mvnw pom.xml ./
RUN apt-get update && apt-get install -y dos2unix
RUN dos2unix ./mvnw
COPY src ./src
RUN ./mvnw package

# Stage 2: Production stage
FROM eclipse-temurin:21-jre-jammy AS production

WORKDIR /app
EXPOSE 8080
COPY --from=base /app/target/spring-petclinic-*.jar /spring-petclinic.jar

ENTRYPOINT ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "/spring-petclinic.jar"]