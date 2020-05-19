#!/usr/bin/env bash
MYSQL_CONTAINER_NAME="${MYSQL_CONTAINER_NAME:-mysql-5.7-for-azure-pipelines-agent}"
MYSQL_CONTAINER_PORT=${MYSQL_CONTAINER_PORT:-3306}
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-pass}"
MYSQL_DATABASE="${MYSQL_DATABASE:-app}"
MYSQL_USER="${MYSQL_USER:-user}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-pass}"
MYSQL_VERSION="${MYSQL_VERSION:-5.7}"

# arm|arm64|amd64
function get_docker_arch() {
    local dockerArch=$(sudo docker version --format '{{.Server.Arch}}') 
    echo "${dockerArch:-unknown}"
}

function is_container_exists() {
    local name=$1
    local exists="true"; 
    sudo docker logs "$name" >/dev/null 2>&1 || exists=false
    echo "$exists"
}

function is_container_running() {
    local name=$1
    local isRunning="false"
    # TODO: filter by names only
    if [[ -n "$(docker ps | grep $name || true)" ]]; then
        isRunning=true
    fi
    echo $isRunning
}

function delete_container() {
    local name=$1
    if [[ "$(is_container_exists ${name})" == true ]]; then
        Say "Deleting existing container $name"
        sudo docker rm -f "$name"
    else
        Say "Skip deleting container $name. It does not exists"
    fi
}

function get_mysql_image_name() {
    local image
    if [[ "$(get_docker_arch)" == arm ]]; then
        # https://github.com/beercan1989/docker-arm-mysql
        image="beercan1989/arm-mysql:latest"
    else 
        image="mysql/mysql-server:${MYSQL_VERSION}"
    fi
    echo $image
}

function delete_image() {
    local image=$1
    Say "Deleting the $image image" 
    docker rmi -f "$image"
}

function stop_container() {
    local name=$1
    if [[ "$(is_container_exists ${name})" == true ]]; then
        Say "Deleting existing container $name"
        sudo docker rm -f "$name"
    else
        Say "Skip deleting container $name. It does not exists"
    fi
}

function start_mysql_container() {
    local image=$(get_mysql_image_name)
    
    if [[ "$(is_container_exists $MYSQL_CONTAINER_NAME)" != true ]]; then
        # container is absent
        Say "Pulling the $image image if required"
        sudo docker pull "$image"
        
        Say "Creating $MYSQL_CONTAINER_NAME container"
        docker run -it \
          -e "MYSQL_ROOT_HOST=%" \
          -e "MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}" \
          -e "MYSQL_DATABASE=${MYSQL_DATABASE}" \
          -e "MYSQL_USER=${MYSQL_USER}" \
          -e "MYSQL_PASSWORD=${MYSQL_PASSWORD}}" \
          -p "${MYSQL_CONTAINER_PORT}:3306" \
          --name $MYSQL_CONTAINER_NAME \
          "$image"
    elif [[ "$(is_container_running $MYSQL_CONTAINER_NAME)" == false ]]; then
        # container exists but stopped
        Say "Starting existing $MYSQL_CONTAINER_NAME container"
        docker start $MYSQL_CONTAINER_NAME
    else 
        Say "Container $MYSQL_CONTAINER_NAME already running"
    fi
}

while [ $# -ne 0 ]; do
    param="$1"
    case "$param" in
        start) start_mysql_container ;;
        reset) delete_container $MYSQL_CONTAINER_NAME; start_mysql_container ;;
        stop) stop_container $MYSQL_CONTAINER_NAME ;;
        delete) delete_container $MYSQL_CONTAINER_NAME ;;
        "delete-image") delete_image $(get_mysql_image_name) ;;
    esac
    shift
done
