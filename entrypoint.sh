#!/usr/bin/env bash -l

IMAGE="$INPUT_IMAGE"
ACCESS_TOKEN="$INPUT_ACCESSTOKEN"
REGISTRY="$INPUT_REGISTRY"
DOCKER_USERNAME="$INPUT_DOCKERHUBUSERNAME"
GCR_HOSTNAME="$INPUT_HOSTNAME"

# Parsing the image name

if [[ -z "$IMAGE" ]]; then
    echo "You must provide the image input"
    exit 1
fi

if [[ $IMAGE =~ ":" ]]; then
    IFS=":" read -ra EL <<< "$IMAGE"
    IMAGE_NAME=${EL[0]}
    TAG=${EL[1]}
else
    IMAGE_NAME=$IMAGE
    TAG="latest"
fi

echo "IMAGE_NAME=$IMAGE_NAME"
echo "TAG=$TAG"

# Setting API base address

case "$REGISTRY" in

    "docker-hub")
        API_ADDRESS="https://registry.hub.docker.com/v2"
        ;;
    "github-packages")
        API_ADDRESS="https://docker.pkg.github.com/v2"
        ;;
    "gcr")
        if [[ -z "$GCR_HOSTNAME" ]]; then
            echo "The input 'hostname' is required"
            exit 1
        fi
        API_ADDRESS="${GCR_HOSTNAME}/v2"
        ;;
    *)
        echo "'$REGISTRY' is not a valid value for the input 'registry'"
        exit 1
        ;;

esac

# Getting a token

case "$REGISTRY" in

    "docker-hub")
        ADDRESS="https://auth.docker.io/token?scope=repository:${IMAGE_NAME}:pull&service=registry.docker.io"
        ARGS=()
        if [[ ! -z "$DOCKER_USERNAME" ]]; then
            if [[ -z "$ACCESS_TOKEN" ]]; then
                echo "If you specify a Docker Hub username, you must also give an access token"
                exit 1
            fi
            ADDRESS+="&account=$DOCKER_USERNAME"
            ARGS+=('-u' "${DOCKER_USERNAME}:$ACCESS_TOKEN")
        fi
        TOKEN=$(curl -sL "${ARGS[@]}" "$ADDRESS" | jq -r '.token')
        ;;

    *)
        TOKEN=$ACCESS_TOKEN
        ;;

esac

if [[ -z "$TOKEN" || "$TOKEN" = "null" ]]; then
    case "$REGISTRY" in
        "github-packages")
            echo "The 'token' input is required when 'registry' is '$REGISTRY'"
            exit 1
            ;;
        "docker-hub")
            echo "Unable to get a token to call the API"
            exit 1
            ;;
    esac
fi

# Getting all the labels

set_headers () {
    if [[ ! -z "$TOKEN" ]]; then
        case "$REGISTRY" in
            "gcr")
                HEADERS=('-u' "_json_key:$TOKEN")
                ;;
            *)
                HEADERS=('-H' "Authorization: Bearer $TOKEN")
                ;;
        esac
    else
        HEADERS=()
    fi
}

ADDRESS="${API_ADDRESS}/${IMAGE_NAME}/manifests/$TAG"
set_headers
HEADERS+=('-H' "Accept: application/vnd.docker.distribution.manifest.v2+json")
DIGEST=$(curl -sL "${HEADERS[@]}" "$ADDRESS" | jq -r '.config.digest')

if [[ -z "$DIGEST" || "$DIGEST" = "null" ]]; then
    MESSAGE="The image '$IMAGE' has not been found"
    if [[ "$REGISTRY" = "gcr" ]]; then
        MESSAGE+=" on $GCR_HOSTNAME"
    fi
    echo "$MESSAGE"
    exit 1
fi

ADDRESS="${API_ADDRESS}/${IMAGE_NAME}/blobs/$DIGEST"
set_headers
LABELS=$(curl -sL "${HEADERS[@]}" "$ADDRESS" | jq -r '.config.Labels')

if [[ -z "$LABELS" || "$LABELS" = "null" ]]; then
    echo "No label has been found"
    exit 0
fi

# Setting output

echo ::set-output name="LABELS"::"$LABELS"
