FROM gitpod/workspace-full

# Install Docker CLI and Docker Compose
USER root

RUN apt-get update && \
    apt-get install -y docker.io docker-compose

# Optionally, add your user to docker group
RUN usermod -aG docker gitpod

USER gitpod
