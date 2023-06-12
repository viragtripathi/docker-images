#!/bin/bash

docker network connect network2 re-node1-cluster1
docker network connect network3 re-node1-cluster1
docker network connect network1 re-node1-cluster2
docker network connect network3 re-node1-cluster2
docker network connect network1 re-node1-cluster3
docker network connect network2 re-node1-cluster3

echo "done"