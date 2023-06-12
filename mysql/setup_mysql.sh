#!/bin/bash

version="${1:-latest}"
db_port="${2:-3306}"
platform="${3:-linux/amd64}"
root_pwd="Redis@123"
db_name="RedisConnect"

container_name="mysql-$version-$(hostname)-$db_port"

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

docker run --name "${container_name}" \
  --platform "${platform}" \
  -v "$(pwd)":/etc/mysql/conf.d \
  -p "${db_port}":3306 \
  -e MYSQL_ROOT_PASSWORD=$root_pwd \
  -d mysql:"${version}"

sleep 30

echo "Creating $db_name database and emp table."
#run the setup script to create the DB and the table in the DB
docker cp mysql_cdc.sql "${container_name}":mysql_cdc.sql
docker exec "${container_name}" bash -c 'mysql -h"localhost" -P3306 -uroot -p"$MYSQL_ROOT_PASSWORD" < mysql_cdc.sql'

echo "done"