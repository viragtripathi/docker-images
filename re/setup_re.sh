#!/bin/bash

version="${1:-latest}"
platform="${2:-linux/amd64}"

container_name="re-node1-$version-$(hostname)"

# Start 1 docker container since we can't do HA with vanilla docker instance. Use docker swarm, RE on VM's or RE K8s operator to achieve HA, clustering etc.

echo "Starting Redis Enterprise as Docker containers..."
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
docker run -d \
  --init \
  --platform "${platform}" \
  --cap-add sys_resource \
  --name "${container_name}" \
	-h "${container_name}" \
	-p 18443:8443 \
	-p 19443:9443 \
	-p 14000-14001:12000-12001 \
	-p 18070:8070 \
	redislabs/redis:"${version}"

while ! nc -vz localhost 18443 < /dev/null
do
  echo "$(date) - still trying"
  sleep 2
done
echo "$(date) - connected to admin ui port successfully"

while ! nc -vz localhost 19443 < /dev/null
do
  echo "$(date) - still trying"
  sleep 2
done
echo "$(date) - connected to rest api port successfully"

while ! nc -vz localhost 18070 < /dev/null
do
  echo "$(date) - still trying"
  sleep 2
done
echo "$(date) - connected to metrics exporter port successfully"

# Create Redis Enterprise cluster
echo "Waiting for the servers to start..."
sleep 60
echo "Creating Redis Enterprise cluster..."

while [[ "$(curl -o /dev/null -w ''%{http_code}'' -X POST -H 'Content-Type:application/json' -d '{"action":"create_cluster","cluster":{"name":"re-cluster.local"},"node":{"paths":{"persistent_path":"/var/opt/redislabs/persist","ephemeral_path":"/var/opt/redislabs/tmp"}},"credentials":{"username":"demo@redis.com","password":"redislabs"}}' -k https://localhost:19443/v1/bootstrap/create_cluster)" != "200" ]]; do sleep 5; done

# Test the cluster. cluster info and nodes
while [[ "$(curl -o ./bootstrap -w ''%{http_code}'' -u demo@redis.com:redislabs -k https://localhost:19443/v1/bootstrap)" != "200" ]]; do sleep 5; done
while [[ "$(curl -o ./nodes -w ''%{http_code}'' -u demo@redis.com:redislabs -k https://localhost:19443/v1/nodes)" != "200" ]]; do sleep 5; done
echo "Bootstrap.." && cat ./bootstrap
echo "Nodes.." && cat ./nodes

# Get the module info to be used for database creation
while [[ "$(curl -o ./modules.txt -w ''%{http_code}'' -u demo@redis.com:redislabs -k https://localhost:19443/v1/modules)" != "200" ]]; do sleep 5; done

json_module_name=$(cat ./modules.txt | grep -oE '"module_name":"[^"]*|"semantic_version":"[^"]*' | grep -iA1 json | cut -d '"' -f 4 | head -1)
json_semantic_version=$(cat ./modules.txt | grep -oE '"module_name":"[^"]*|"semantic_version":"[^"]*' | grep -iA1 json | cut -d '"' -f 4 | tail -1)
search_module_name=$(cat ./modules.txt | grep -oE '"module_name":"[^"]*|"semantic_version":"[^"]*' | grep -iA1 search | cut -d '"' -f 4 | head -1)
search_semantic_version=$(cat ./modules.txt | grep -oE '"module_name":"[^"]*|"semantic_version":"[^"]*' | grep -iA1 search | cut -d '"' -f 4 | tail -1)
timeseries_module_name=$(cat ./modules.txt | grep -oE '"module_name":"[^"]*|"semantic_version":"[^"]*' | grep -iA1 timeseries | cut -d '"' -f 4 | head -1)
timeseries_semantic_version=$(cat ./modules.txt | grep -oE '"module_name":"[^"]*|"semantic_version":"[^"]*' | grep -iA1 timeseries | cut -d '"' -f 4 | tail -1)

while [[ "$(curl -o ./virag -w ''%{http_code}'' -u demo@redis.com:redislabs -X POST -H "Content-Type: application/json" -d "{\"email\": \"virag@redis.com\",\"password\": \"Redis123\",\"name\": \"virag\",\"email_alerts\": false,\"role\": \"db_member\"}" -k https://localhost:19443/v1/users)" != "200" ]]; do sleep 5; done
while [[ "$(curl -o ./allen -w ''%{http_code}'' -u demo@redis.com:redislabs -X POST -H "Content-Type: application/json" -d "{\"email\": \"allen@redis.com\",\"password\": \"Redis123\",\"name\": \"allen\",\"email_alerts\": false,\"role\": \"db_member\"}" -k https://localhost:19443/v1/users)" != "200" ]]; do sleep 5; done
echo "User virag.." && cat ./virag
echo "User allen.." && cat ./allen

echo "Creating databases..."
echo Creating Redis Target database with "${search_module_name}" version "${search_semantic_version}" and "${json_module_name}" version "${json_semantic_version}"
while [[ "$(curl -o ./Target -w ''%{http_code}'' -u demo@redis.com:redislabs --location-trusted -H "Content-type:application/json" -d '{ "name": "Target", "port": 12000, "memory_size": 500000000, "type" : "redis", "replication": false, "default_user": false, "roles_permissions": [{"role_uid": 4, "redis_acl_uid": 1}], "module_list": [ {"module_args": "PARTITIONS AUTO", "module_name": "'"$search_module_name"'", "semantic_version": "'"$search_semantic_version"'"}, {"module_args": "", "module_name": "'"$json_module_name"'", "semantic_version": "'"$json_semantic_version"'"} ] }' -k https://localhost:19443/v1/bdbs)" != "200" ]]; do sleep 5; done
echo "Database Target.." && cat ./Target

echo Creating Redis JobManager database with "${timeseries_module_name}" version "${timeseries_semantic_version}"
while [[ "$(curl -o ./JobManager -w ''%{http_code}'' -u demo@redis.com:redislabs --location-trusted -H "Content-type:application/json" -d '{"name": "JobManager", "type":"redis", "replication": false, "memory_size": 250000000, "port": 12001, "default_user": false, "roles_permissions": [{"role_uid": 4, "redis_acl_uid": 1}], "module_list": [{"module_args": "", "module_name": "'"$timeseries_module_name"'", "semantic_version": "'"$timeseries_semantic_version"'"} ] }' -k https://localhost:19443/v1/bdbs)" != "200" ]]; do sleep 5; done
echo "Database JobManager.." && cat ./JobManager

echo "Database port mappings per node. We are using mDNS so use the IP and exposed port to connect to the databases."
echo "node1:"
docker port "${container_name}" | grep -e "12000|12001"

# Enable bdb name
docker exec -it "${container_name}" bash -c "/opt/redislabs/bin/ccs-cli hset cluster_settings metrics_exporter_expose_bdb_name enabled"
docker exec -it "${container_name}" bash -c "/opt/redislabs/bin/supervisorctl restart metrics_exporter"

echo "------- RLADMIN status -------"
docker exec "${container_name}" bash -c "rladmin status"
echo ""
echo "You can open a browser and access Redis Enterprise Admin UI at https://127.0.0.1:18443 (replace localhost with your ip/host) with username=demo@redis.com and password=redislabs."
echo "DISCLAIMER: This is best for local development or functional testing. Please see, https://docs.redis.com/latest/rs/installing-upgrading/quickstarts/docker-quickstart/"

# Cleanup
rm bootstrap nodes modules.txt allen virag Target JobManager

echo "done"
