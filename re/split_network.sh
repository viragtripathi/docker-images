#!/bin/bash

docker network disconnect network2 re-node1-cluster1
docker network disconnect network3 re-node1-cluster1
docker network disconnect network1 re-node1-cluster2
docker network disconnect network3 re-node1-cluster2
docker network disconnect network1 re-node1-cluster3
docker network disconnect network2 re-node1-cluster3

echo "done"