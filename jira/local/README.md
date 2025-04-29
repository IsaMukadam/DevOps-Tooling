# Local Jira Server Setup

This setup includes Jira Server and PostgreSQL database running in Docker containers.

## Prerequisites

- Docker and Docker Compose installed on your system
- At least 4GB of RAM available for Jira

## Getting Started

1. Start the containers:
   ```bash
   docker-compose up -d
   ```

2. Access Jira:
   - Open your browser and navigate to `http://localhost:8080`
   - Follow the setup wizard
   - When configuring the database:
     - Choose "PostgreSQL"
     - Database URL: jdbc:postgresql://postgres:5432/jiradb
     - Username: jira
     - Password: jirapass

## Notes

- Initial startup may take a few minutes
- Data is persisted in Docker volumes:
  - `jira_data`: Jira application data
  - `postgres_data`: PostgreSQL database data

## Stopping the Services

To stop the containers:
```bash
docker-compose down
```

To stop and remove all data (volumes):
```bash
docker-compose down -v
```