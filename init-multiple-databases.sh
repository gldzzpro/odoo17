#!/bin/bash

# init-multiple-databases.sh
# PostgreSQL initialization script for creating multiple databases and users
# This script is executed during PostgreSQL container initialization

set -e
set -u

# Function to create database and user
create_user_and_database() {
    local database=$1
    local user=$2
    local password=$3
    
    echo "Creating user '$user' and database '$database'..."
    
    # Create user if it doesn't exist
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$user') THEN
                CREATE ROLE $user LOGIN PASSWORD '$password';
            END IF;
        END
        \$\$;
EOSQL
    
    # Create database if it doesn't exist
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        SELECT 'CREATE DATABASE $database OWNER $user'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$database')\gexec
EOSQL
    
    # Grant privileges
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        GRANT ALL PRIVILEGES ON DATABASE $database TO $user;
EOSQL
    
    echo "User '$user' and database '$database' created successfully."
}

# Parse environment variables
if [ -n "${POSTGRES_MULTIPLE_DATABASES:-}" ]; then
    echo "Creating multiple databases: $POSTGRES_MULTIPLE_DATABASES"
    
    # Split databases by comma
    IFS=',' read -ra DATABASES <<< "$POSTGRES_MULTIPLE_DATABASES"
    
    # Parse users if provided
    if [ -n "${POSTGRES_MULTIPLE_USERS:-}" ]; then
        IFS=',' read -ra USERS <<< "$POSTGRES_MULTIPLE_USERS"
        
        # Create databases with corresponding users
        for i in "${!DATABASES[@]}"; do
            database="${DATABASES[i]}"
            
            if [ -n "${USERS[i]:-}" ]; then
                # Parse user:password format
                IFS=':' read -ra USER_PASS <<< "${USERS[i]}"
                user="${USER_PASS[0]}"
                password="${USER_PASS[1]:-$user}"
                
                create_user_and_database "$database" "$user" "$password"
            else
                # Create database with default user
                create_user_and_database "$database" "$POSTGRES_USER" "$POSTGRES_PASSWORD"
            fi
        done
    else
        # Create databases with default user
        for database in "${DATABASES[@]}"; do
            create_user_and_database "$database" "$POSTGRES_USER" "$POSTGRES_PASSWORD"
        done
    fi
fi

echo "Database initialization completed."