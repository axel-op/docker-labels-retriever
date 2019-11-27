#!/usr/bin/env bash -l

IMAGE="$INPUT_IMAGE"
TOKEN="$INPUT_GITHUBTOKEN"
REGISTRY="$INPUT_REGISTRY"

# Checking and parsing the inputs

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
    TOKEN=$(curl -s -f "https://auth.docker.io/token?scope=repository:${IMAGE_NAME}:pull&service=registry.docker.io" | jq -r '.token')
fi

# Checking the token

if [[ -z "$TOKEN" || "$TOKEN" = "null" ]]; then
    if [[ "$REGISTRY" = "github-packages" ]]; then
        echo "The 'token' input is required when 'registry' is 'github-packages'"
    else
        echo "Unable to get a token to call the API"
    fi
    exit 1
fi

# Getting all the labels

declare -a HEADERS=('-H' "Accept: application/vnd.docker.distribution.manifest.v2+json" '-H' "Authorization: Bearer $TOKEN")
DIGEST=$(curl -s -f "${HEADERS[@]}" "${API_ADDRESS}/${IMAGE_NAME}/manifests/$TAG" | jq -r '.config.digest')

if [[ -z "$DIGEST" || "$DIGEST" = "null" ]]; then
    echo "The image '$IMAGE' has not been found"
    exit 1
fi

LABELS_JSON=$(curl -s -f -L -H "Authorization: Bearer $TOKEN" "${API_ADDRESS}/${IMAGE_NAME}/blobs/$DIGEST" | jq -r ".config.Labels")

if [[ -z "$LABELS_JSON" || "$LABELS_JSON" = "null" ]]; then
    echo "No label has been found"
    exit 0
fi

KEYS=$(jq -r ". | keys[]" <<< $LABELS_JSON)

# Setting outputs

for KEY in $KEYS
do
    VALUE=$(jq -r ".[\"$KEY\"]" <<< $LABELS_JSON)
    echo ::set-output name="$KEY"::"$VALUE"
done
