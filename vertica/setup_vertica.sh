#!/bin/bash

version="${1:-latest}"
db_port="${2:-5433}"
platform="${3:-linux/amd64}"
db_user=redisconnect
db_pwd=Redis123

container_name="vertica-$version-$(hostname)-$db_port"

echo "Creating $container_name docker container."
docker run \
  --name "${container_name}" \
  --platform "${platform}" \
  -p "${db_port}":5433 \
  -e APP_DB_USER=$db_user \
  -e APP_DB_PASSWORD=$db_pwd \
  -e VERTICA_DB_NAME="RedisConnect" \
  -d vertica/vertica-ce:"${version}"

ip=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${container_name}")

while ! nc -vz "${ip}" 5433 < /dev/null
do
  echo "$(date) - still trying"
  sleep 2
done
echo "$(date) - connected successfully"

attempt=0
while [ $attempt -le 400 ]; do
    attempt=$(( "${attempt}" + 1 ))
    echo "$(date) - Waiting for vertica database to be up (attempt: $attempt)..."
    result=$(docker logs "${container_name}")
    if grep -q 'Vertica is now running' <<< "${result}" ; then
      echo "$(date) - $container_name is up!"
      break
    fi
    sleep 5
done

echo "done"