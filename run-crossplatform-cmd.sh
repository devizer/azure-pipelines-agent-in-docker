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
  Say "$info for [${TAG}] running [${arch}]"
  docker run -t --rm "devizervlad/crossplatform-azure-pipelines-agent:${TAG}@${sha}" bash -c "$cmd" || exit 1
fi
