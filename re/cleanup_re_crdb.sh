#!/bin/bash

version="${1:-latest}"
cleanup="${2:-yes}"

container_one="re-node1-cluster1-$version-$(hostname)"
container_two="re-node1-cluster2-$version-$(hostname)"
container_three="re-node1-cluster3-$version-$(hostname)"

# delete the existing container if it exist
if [ "${cleanup}" = "yes" ]; then
  docker network rm network1 2>/dev/null
  docker network rm network2 2>/dev/null
  docker network rm network3 2>/dev/null

  echo "Stopping and removing ${container_one} docker container from $(hostname)."
  docker container stop "${container_one}"; docker container rm "${container_one}";
  echo "Stopping and removing ${container_two} docker container from $(hostname)."
  docker container stop "${container_two}"; docker container rm "${container_two}";
  echo "Stopping and removing ${container_three} docker container from $(hostname)."
  docker container stop "${container_three}"; docker container rm "${container_three}";
else
  echo "Skipping removing ${container_one} docker container from $(hostname)."
  echo "Skipping removing ${container_two} docker container from $(hostname)."
  echo "Skipping removing ${container_three} docker container from $(hostname)."
fi

echo "done"