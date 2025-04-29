# Local Jira Setup

This directory contains Docker Compose configurations for running Jira with PostgreSQL locally.

## Configurations

Three different deployment options are available:

### 1. Docker Volume Mount (`docker-compose-docker-volume.yml`)
- Uses Docker named volumes
- Data persists across container restarts
- Volumes managed by Docker

### 2. Local Directory Mount (`docker-compose-local-mount.yml`)
- Mounts local directories for data
- Easy access to data files
- Data stored in `./data/{jira,postgres}`

### 3. Enhanced Configuration (`docker-compose-local-enhanced.yml`)
- Includes health checks
- Memory limits configured
- Network isolation
- Optimized PostgreSQL settings
- Automatic container restart

## Quick Start

1. Choose your preferred configuration:
```bash
docker-compose -f <config-file>.yml up -d
```

2. Access Jira at: http://localhost:8080

## Database Configuration

PostgreSQL settings:
- Database: jiradb
- Username: jira
- Password: jirapass
- Host: postgres
- Port: 5432

## Resource Allocation

### Jira
- Memory Limit: 4GB
- Memory Reservation: 2GB

### PostgreSQL
- Memory Limit: 2GB
- Memory Reservation: 1GB

## Data Persistence
Data is stored either in Docker volumes or local directories depending on the chosen configuration:
- Docker volumes: `jira_data` and `postgres_data`
- Local directories: `./data/jira` and `./data/postgres`