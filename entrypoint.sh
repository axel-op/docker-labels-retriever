#!/usr/bin/env bash -l

IMAGE="$INPUT_IMAGE"
TOKEN="$INPUT_GITHUBTOKEN"
REGISTRY="$INPUT_REGISTRY"
DOCKER_USERNAME="$INPUT_DOCKERHUBUSERNAME"
DOCKER_PASSWORD="$INPUT_DOCKERHUBPASSWORD"

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
        API_ADDRESS="https://registry-1.docker.io/v2"
        ;;
    "github-packages")
        API_ADDRESS="https://docker.pkg.github.com/v2"
        ;;
    *)
        echo "'$REGISTRY' is not a valid value for the input 'registry'"
        exit 1
        ;;

esac

# Getting a token with Docker API

if [[ "$REGISTRY" = "docker-hub" ]]; then
    ADDRESS="https://auth.docker.io/token?scope=repository:${IMAGE_NAME}:pull&service=registry.docker.io"
    ARGS=()
    if [[ ! -z "$DOCKER_USERNAME" ]]; then
        if [[ -z "$DOCKER_PASSWORD" ]]; then
            echo "If you specify a Docker Hub username, you must also give the password or an access token"
            exit 1
        fi
        ADDRESS+="&account=$DOCKER_USERNAME"
        ARGS+=('-u' "${DOCKER_USERNAME}:${DOCKER_PASSWORD}")
    fi
    TOKEN=$(curl -sL "${ARGS[@]}" "$ADDRESS" | jq -r '.token')
fi

# Checking the token

if [[ -z "$TOKEN" || "$TOKEN" = "null" ]]; then
    if [[ "$REGISTRY" = "github-packages" ]]; then
        echo "The 'githubToken' input is required when 'registry' is '$REGISTRY'"
    else
        echo "Unable to get a token to call the API"
    fi
    exit 1
fi

# Getting all the labels

ADDRESS="${API_ADDRESS}/${IMAGE_NAME}/manifests/$TAG"
HEADERS=('-H' "Accept: application/vnd.docker.distribution.manifest.v2+json" '-H' "Authorization: Bearer $TOKEN")
DIGEST=$(curl -sL "${HEADERS[@]}" "$ADDRESS" | jq -r '.config.digest')

if [[ -z "$DIGEST" || "$DIGEST" = "null" ]]; then
    echo "The image '$IMAGE' has not been found"
    exit 1
fi

ADDRESS="${API_ADDRESS}/${IMAGE_NAME}/blobs/$DIGEST"
HEADERS=('-H' "Authorization: Bearer $TOKEN")
LABELS=$(curl -sL "${HEADERS[@]}" "$ADDRESS" | jq -r '.config.Labels')

if [[ -z "$LABELS" || "$LABELS" = "null" ]]; then
    echo "No label has been found"
    exit 0
fi

# Setting outputs

for KEY in $(jq -r ". | keys[]" <<< $LABELS)
do
    VALUE=$(jq -r ".[\"$KEY\"]" <<< $LABELS)
    echo ::set-output name="$KEY"::"$VALUE"
done
