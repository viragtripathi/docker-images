#!/bin/bash

version="${1:-2019-latest}"
db_port="${2:-1433}"
platform="${3:-linux/amd64}"
db_pwd="Redis@123"

container_name="mssql-$version-$(hostname)-$db_port"

echo "Creating $container_name docker container."
IS_RUNNING=$(docker ps --filter name="${container_name}" --format '{{.ID}}')
if [ -n "${IS_RUNNING}" ]; then
    echo "${container_name} is running. Stopping ${container_name} and removing container..."
    docker container stop "${container_name}"
    docker container rm "${container_name}"
else
    IS_STOPPED=$(docker ps -a --filter name="${container_name}" --format '{{.ID}}')
    if [ -n "${IS_STOPPED}" ]; then
        echo "${container_name} is stopped. Removing container..."
        docker container rm "${container_name}"
    fi
fi

docker run \
  --init \
  --name "${container_name}" \
  --platform "${platform}" \
  -e "ACCEPT_EULA=Y" \
  -e SA_PASSWORD=$db_pwd \
  -e "MSSQL_AGENT_ENABLED=true" \
  -e "MSSQL_MEMORY_LIMIT_MB=2GB" \
  -p "${db_port}":1433 \
  -d mcr.microsoft.com/mssql/server:"${version}"

sleep 60

echo "Creating RedisConnect database and emp table."
#run the setup script to create the DB and the table in the DB
docker cp mssql_cdc.sql "${container_name}":mssql_cdc.sql
docker exec "${container_name}" bash -c '/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -i mssql_cdc.sql'

echo "done"