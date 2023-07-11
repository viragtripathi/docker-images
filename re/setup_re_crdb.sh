#!/bin/bash

version="${1:-latest}"
platform="${2:-linux/amd64}"

container_one="re-node1-cluster1-$version-$(hostname)"
container_two="re-node1-cluster2-$version-$(hostname)"
container_three="re-node1-cluster3-$version-$(hostname)"

# Delete bridge networks if they already exist
docker network rm network1 2>/dev/null
docker network rm network2 2>/dev/null
docker network rm network3 2>/dev/null

# Create new bridge networks
echo "Creating new subnets..."
docker network create network1 --subnet=172.18.0.0/16 --gateway=172.18.0.1
docker network create network2 --subnet=172.19.0.0/16 --gateway=172.19.0.1
docker network create network3 --subnet=172.20.0.0/16 --gateway=172.20.0.1

# Add entries to /etc/hosts so A-A can work without DNS setup
cluster1=$(grep cluster1.local /etc/hosts | cut -d ' ' -f 2)
if [ -n "$cluster1" ]
then
   echo "cluster1.local entry exists in /etc/hosts. Skipping.."
else
   echo "Adding cluster1.local entry to /etc/hosts.."
   echo "172.18.0.2 cluster1.local" | sudo tee -a /etc/hosts
fi
cluster2=$(grep cluster2.local /etc/hosts | cut -d ' ' -f 2)
if [ -n "$cluster2" ]
then
   echo "cluster2.local entry exists in /etc/hosts. Skipping.."
else
   echo "Adding cluster2.local entry to /etc/hosts.."
   echo "172.19.0.2 cluster2.local" | sudo tee -a /etc/hosts
fi
cluster3=$(grep cluster3.local /etc/hosts | cut -d ' ' -f 2)
if [ -n "$cluster3" ]
then
   echo "cluster3.local entry exists in /etc/hosts. Skipping.."
else
   echo "Adding cluster3.local entry to /etc/hosts.."
   echo "172.20.0.2 cluster3.local" | sudo tee -a /etc/hosts
fi

# Start 3 sudo docker containers. Each container is a node in a separate network
echo "Starting Redis Enterprise as Docker containers..."
docker run -d \
  --init \
  --platform "${platform}" \
  --cap-add sys_resource \
  --name "${container_one}" \
	-h "${container_one}" \
	-p 8443:8443 \
	-p 9443:9443 \
	-p 14000-14001:12000-12001 \
	-p 8071:8070 \
	--network=network1 \
	--ip=172.18.0.2 \
	redislabs/redis:"${version}"

docker run -d \
  --init \
  --platform "${platform}" \
  --cap-add sys_resource \
  --name "${container_two}" \
	-h "${container_two}" \
	-p 8445:8443 \
	-p 9445:9443 \
	-p 14002:12000 \
	-p 8072:8070 \
	--network=network2 \
	--ip=172.19.0.2 \
	redislabs/redis:"${version}"

docker run -d \
  --init \
  --platform "${platform}" \
  --cap-add sys_resource \
  --name "${container_three}" \
	-h "${container_three}" \
	-p 8447:8443 \
	-p 9447:9443 \
	-p 14004:12000 \
	-p 8073:8070 \
	--network=network3 \
	--ip=172.20.0.2 \
	redislabs/redis:"${version}"

while ! nc -vz localhost 8443 < /dev/null
do
  echo "$(date) - still trying"
  sleep 2
done
echo "$(date) - connected to admin ui port successfully"

while ! nc -vz localhost 9443 < /dev/null
do
  echo "$(date) - still trying"
  sleep 2
done
echo "$(date) - connected to rest api port successfully"

while ! nc -vz localhost 8071 < /dev/null
do
  echo "$(date) - still trying"
  sleep 2
done
echo "$(date) - connected to metrics exporter port successfully"

# Create Redis Enterprise cluster
echo "Waiting for the servers to start..."
sleep 120
echo "Creating Redis Enterprise clusters..."

tee -a ./create_cluster1.sh <<EOF
/opt/redislabs/bin/rladmin cluster create name cluster1.local username demo@redis.com password redislabs
EOF

chmod a+x create_cluster1.sh
docker cp create_cluster1.sh "${container_one}":/opt/create_cluster1.sh
docker exec --user root "${container_one}" bash -c "/opt/create_cluster1.sh > create_cluster1.out"
sleep 60
docker cp "${container_one}":/opt/create_cluster1.out .

if [ "$(grep -c "ok" ./create_cluster1.out)" -eq 1 ]; then
  cat ./create_cluster1.out
else
  echo "The output file does not contain the expected output"
fi

tee -a ./create_cluster2.sh <<EOF
/opt/redislabs/bin/rladmin cluster create name cluster2.local username demo@redis.com password redislabs
EOF

chmod a+x create_cluster2.sh
docker cp create_cluster2.sh "${container_two}":/opt/create_cluster2.sh
docker exec --user root "${container_two}" bash -c "/opt/create_cluster2.sh > create_cluster2.out"
sleep 60
docker cp "${container_two}":/opt/create_cluster2.out .

if [ "$(grep -c "ok" ./create_cluster2.out)" -eq 1 ]; then
  cat ./create_cluster2.out
else
  echo "The output file does not contain the expected output"
fi

tee -a ./create_cluster3.sh <<EOF
/opt/redislabs/bin/rladmin cluster create name cluster3.local username demo@redis.com password redislabs
EOF

chmod a+x create_cluster3.sh
docker cp create_cluster3.sh "${container_three}":/opt/create_cluster3.sh
docker exec --user root "${container_three}" bash -c "/opt/create_cluster3.sh > create_cluster3.out"
sleep 60
docker cp "${container_three}":/opt/create_cluster3.out .

if [ "$(grep -c "ok" ./create_cluster3.out)" -eq 1 ]; then
  cat ./create_cluster3.out
else
  echo "The output file does not contain the expected output"
fi
# Test the cluster. cluster info and nodes
curl -s -u demo@redis.com:redislabs -k https://localhost:9443/v1/bootstrap
curl -s -u demo@redis.com:redislabs -k https://localhost:9443/v1/nodes

# Get the module info to be used for database creation
tee -a ./list_modules.sh <<EOF
curl -s -k -L -u demo@redis.com:redislabs --location-trusted -H "Content-Type: application/json" -X GET https://localhost:9443/v1/modules | python -c 'import sys, json; modules = json.load(sys.stdin);
modulelist = open("./module_list.txt", "a")
for i in modules:
     lines = i["display_name"], " ", i["module_name"], " ", i["uid"], " ", i["semantic_version"], "\n"
     modulelist.writelines(lines)
modulelist.close()'
EOF

docker cp list_modules.sh "${container_one}":/opt/list_modules.sh
docker exec --user root "${container_one}" bash -c "chmod a+x /opt/list_modules.sh"
docker exec --user root "${container_one}" bash -c "/opt/list_modules.sh"
docker cp "${container_one}":/opt/module_list.txt .

json_module_name=$(grep -i json ./module_list.txt | cut -d ' ' -f 2)
json_semantic_version=$(grep -i json ./module_list.txt | cut -d ' ' -f 4)
search_module_name=$(grep -i search ./module_list.txt | cut -d ' ' -f 3)
search_semantic_version=$(grep -i search ./module_list.txt | cut -d ' ' -f 5)
timeseries_module_name=$(grep -i timeseries ./module_list.txt | cut -d ' ' -f 2)
timeseries_semantic_version=$(grep -i timeseries ./module_list.txt | cut -d ' ' -f 4)

curl -s -X POST -k -u demo@redis.com:redislabs -H "Content-Type: application/json" -d "{\"email\": \"virag@redis.com\",\"password\": \"Redis123\",\"name\": \"virag\",\"email_alerts\": false,\"role\": \"db_member\"}" https://localhost:19443/v1/users
curl -s -X POST -k -u demo@redis.com:redislabs -H "Content-Type: application/json" -d "{\"email\": \"allen@redis.com\",\"password\": \"Redis123\",\"name\": \"allen\",\"email_alerts\": false,\"role\": \"db_member\"}" https://localhost:19443/v1/users

echo "Creating databases..."
echo Creating Redis Target database with "${search_module_name}" version "${search_semantic_version}" and "${json_module_name}" version "${json_semantic_version}"
curl -s -k -L -u demo@redis.com:redislabs --location-trusted -H "Content-type:application/json" -d '{ "default_db_config": { "name": "Target", "port": 12000, "memory_size": 500000000, "type" : "redis", "replication": false, "aof_policy": "appendfsync-every-sec", "snapshot_policy": [], "shards_count": 1, "shard_key_regex": [{"regex": ".*\\\\{(?<tag>.*)\\\\}.*"}, {"regex": "(?<tag>.*)"}], "default_user": true, "roles_permissions": [{"role_uid": 4, "redis_acl_uid": 1}], "module_list": [ {"module_args": "PARTITIONS AUTO", "module_name": "'"$search_module_name"'", "semantic_version": "'"$search_semantic_version"'"}, {"module_args": "", "module_name": "'"$json_module_name"'", "semantic_version": "'"$json_semantic_version"'"} ] }, "instances": [{"cluster": {"url": "https://cluster1.local:9443","credentials": {"username": "demo@redis.com", "password": "redislabs"}, "name": "cluster1.local"}, "compression": 6}, {"cluster": {"url": "https://cluster2.local:9443", "credentials": {"username": "demo@redis.com", "password": "redislabs"}, "name": "cluster2.local"}, "compression": 6}, {"cluster": {"url": "https://cluster3.local:9443", "credentials": {"username": "demo@redis.com", "password": "redislabs"}, "name": "cluster3.local"}, "compression": 6}], "name": "Target" }' https://localhost:9443/v1/crdbs
echo Creating Redis JobManager database with "${timeseries_module_name}" version "${timeseries_semantic_version}"
curl -s -k -L -u demo@redis.com:redislabs --location-trusted -H "Content-type:application/json" -d '{"name": "JobManager", "type":"redis", "replication": false, "memory_size": 250000000, "port": 12001, "default_user": false, "roles_permissions": [{"role_uid": 4, "redis_acl_uid": 1}], "module_list": [{"module_args": "", "module_name": "'"$timeseries_module_name"'", "semantic_version": "'"$timeseries_semantic_version"'"} ] }' https://localhost:9443/v1/bdbs

sleep 30

echo "Database port mappings per node. We are using mDNS so use the IP and exposed port to connect to the databases."
echo "node1:"
docker port "${container_one}" | grep -e "12000|12001"

echo "------- RLADMIN status -------"
docker exec "${container_one}" bash -c "rladmin status"
echo ""
echo "You can open a browser and access Redis Enterprise Admin UI at https://127.0.0.1:8443 (replace localhost with your ip/host) with username=demo@redis.com and password=redislabs."
echo "DISCLAIMER: This is best for local development or functional testing. Please see, https://docs.redis.com/latest/rs/getting-started/getting-started-docker"

# Cleanup
rm list_modules.sh create_cluster.* module_list.txt
docker exec --user root "${container_one}" bash -c "rm /opt/list_modules.sh"
docker exec --user root "${container_one}" bash -c "rm /opt/module_list.txt"
docker exec --user root "${container_one}" bash -c "rm /opt/create_cluster.*"

echo "done"