#!/usr/bin/env bash
arch=arm64 # arm64 | arm | amd64
arch=$1
info=$2
cmd=$3

json=$(docker buildx imagetools inspect --raw "devizervlad/crossplatform-azure-pipelines-agent:${TAG}")
# echo $json | jq -r '.manifests[].platform.architecture'
sha=$(echo $json | jq -r '.manifests[] | if .platform.architecture == "'$arch'" then .digest else "" end' | grep -v -e '^$')
if [[ "$sha" == "" ]]; then
  Say "Skipping: architecture [$arch] not found for ${TAG}"
else
  Say "${TAG}:$info Removing all the containers and images"
  docker rm -f $(docker ps -aq) 
  docker image rm $(docker image ls -a -q) 
  docker image rm -f devizervlad/crossplatform-azure-pipelines-agent >/dev/null
  docker image rm -f $(docker image ls | grep devizervlad/crossplatform-azure-pipelines-agent | awk '{print $3}') # >/dev/null 2>/dev/null
  Say "${TAG}:$info Containers"
  docker ps -a
  Say "${TAG}:$info Images"
  docker image ls
  Say "${TAG}:$info Free space"
  df -T

  Say "${TAG}:$info Pull devizervlad/crossplatform-azure-pipelines-agent:${TAG}@${sha} for [${TAG}] running [${arch}]"
  docker pull "devizervlad/crossplatform-azure-pipelines-agent:${TAG}@${sha}" >/dev/null
  Say "${TAG}:$info for [${TAG}] running [${arch}]"
  docker run -t --rm "devizervlad/crossplatform-azure-pipelines-agent:${TAG}@${sha}" bash -c "$cmd" || exit 1
  Say "${TAG}:$info finished"
fi
