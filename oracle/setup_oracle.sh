#!/bin/bash

# Please build the oracle container image prior to running this setup script. See here, https://github.com/oracle/docker-images
# https://github.com/oracle/docker-images/blob/main/OracleDatabase/SingleInstance/README.md
# ./buildContainerImage.sh -i -e -v 12.2.0.1
# OR
# Use a pre-built image

version="${1:-19.3.0-ee}"
db_port="${2:-1521}"
logminer="${3:-logminer}"
platform="${4:-linux/amd64}"
db_pwd=Redis123

container_name="oracle-$version-$(hostname)-$db_port"

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

echo "Creating $container_name docker container."
docker run \
  --init \
  --name "${container_name}" \
  --privileged=true \
  --platform "${platform}" \
	-p "${db_port}":1521 \
	-e ORACLE_PWD=$db_pwd \
  -d virag/oracle-"${version}"

ip=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${container_name}")

while ! nc -vz "${ip}" 1521 < /dev/null
do
  echo "$(date) - still trying"
  sleep 2
done
echo "$(date) - connected successfully"

attempt=0
while [ $attempt -le 400 ]; do
    attempt=$(( "${attempt}" + 1 ))
    echo "$(date) - Waiting for oracle database to be up (attempt: $attempt)..."
    result=$(docker logs "${container_name}")
    if grep -q 'DATABASE IS READY TO USE!' <<< "${result}" ; then
      echo "$(date) - $container_name is up!"
      break
    fi
    sleep 5
done

#Check if the logminer option is provided or not
if [ $# -eq 3 ] && [ "$logminer" = "logminer" ]; then
	echo "Setting up LogMiner and creating C##RCUSER schema on $container_name.."
	docker cp setup_logminer.sh "${container_name}":/tmp/setup_logminer.sh
	docker cp load_c##rcuser_schema.sh "${container_name}":/tmp/load_c##rcuser_schema.sh
	docker exec "${container_name}" bash -c "/tmp/setup_logminer.sh"
	docker exec "${container_name}" bash -c "/tmp/load_c##rcuser_schema.sh"
else
	echo "Skipping LogMiner setup.."
fi

echo "done"