#!/bin/bash

version="${1:-latest}"
db_port="${2:-50000}"
platform="${3:-linux/amd64}"

db_name="rcdb2"
db_instance="db2inst1"
db_pwd="rcdbpwd"

container_name="db2-$version-$(hostname)-$db_port"

echo "Creating $container_name docker container."
docker run \
  --init \
  --name "${container_name}" \
  --privileged=true \
  --platform "${platform}" \
	-e LICENSE=accept \
	-e DB2INSTANCE=$db_instance \
	-e DB2INST1_PASSWORD=$db_pwd \
	-e DBNAME=$db_name \
	-e BLU=false \
	-e ENABLE_ORACLE_COMPATIBILITY=false \
	-e UPDATEAVAIL=NO \
	-e TO_CREATE_SAMPLEDB=false \
	-e REPODB=false \
	-e IS_OSXFS=false \
	-e PERSISTENT_HOME=true \
	-e HADR_ENABLED=false \
	-e ETCD_ENDPOINT= \
	-e ETCD_USERNAME= \
	-e ETCD_PASSWORD= \
	-p "${db_port}":50000 \
	-d icr.io/db2_community/db2:"${version}"

ip=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${container_name}")

while ! nc -vz "${ip}" 50000 < /dev/null
do
  echo "$(date) - still trying"
  sleep 2
done
echo "$(date) - connected successfully"

echo "Creating $db_name database on $db_instance DB2 instance."
attempt=0
while [ $attempt -le 400 ]; do
    attempt=$(( "${attempt}" + 1 ))
    echo "$(date) - Waiting for $db_name database to be up (attempt: $attempt)..."
    result=$(docker logs "${container_name}")
    if grep -q 'Setup has completed' <<< "${result}" ; then
      echo "$(date) - $container_name is up!"
      break
    fi
    sleep 5
done

echo "Creating emp table on $db_name database."
#run the setup script to create the DB and the table in the DB
docker exec --user $db_instance "${container_name}" bash -c '$HOME/sqllib/bin/db2ilist'
docker exec --user $db_instance "${container_name}" bash -c '$HOME/sqllib/adm/db2licm -l'
docker exec --user $db_instance "${container_name}" bash -c '$HOME/sqllib/bin/db2 list database directory'
docker exec --user $db_instance "${container_name}" bash -c '$HOME/sqllib/bin/db2 activate database $DBNAME'
docker cp create_emp_table.sql "${container_name}":/var/tmp/create_emp_table.sql
docker cp setup_emp_table.sh "${container_name}":/var/tmp/setup_emp_table.sh
docker cp ../data/emp.csv "${container_name}":/var/tmp/emp.csv
docker exec --user $db_instance "${container_name}" bash -c '/var/tmp/setup_emp_table.sh'

echo "done"