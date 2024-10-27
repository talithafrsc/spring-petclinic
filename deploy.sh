#!/bin/bash

reload_nginx() {
    docker exec nginx /usr/sbin/nginx -s reload
}

# Authenticate to registry
gcloud auth configure-docker asia-docker.pkg.dev --quiet

# Ensure current containers are running
docker compose up -d

# Get current running petclinic container name
OLD_CONTAINER=$(docker ps --format "{{.Names}}" | grep petclinic)

# Deploy new container
docker compose up -d --no-deps --scale petclinic-app=2 --no-recreate petclinic-app
reload_nginx

# Get new running petclinic container name
NEW_CONTAINER=$(docker ps --latest --format "{{.Names}}")

# Check liveness of new container
while true; do
    if docker exec $NEW_CONTAINER curl -I --silent --fail http://localhost:8080; then
        echo "Service is running!"
        break
    else
        echo "Waiting for service to be available..."
        sleep 1
    fi
done

# Stopping the old container
docker stop $OLD_CONTAINER
docker rm $OLD_CONTAINER
reload_nginx

# Scale down the container
docker compose up -d --no-deps --scale petclinic-app=1
reload_nginx