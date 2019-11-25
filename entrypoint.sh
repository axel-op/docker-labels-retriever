#!/usr/bin/env bash -l

IMAGE="$INPUT_IMAGE"
LABEL="$INPUT_LABEL"

if [[ -z "$IMAGE" || -z "$LABEL" ]]; then
    echo "You must provide the required inputs"
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

TOKEN=$(curl -s "https://auth.docker.io/token?scope=repository:${IMAGE_NAME}:pull&service=registry.docker.io" | jq -r '.token')

if [[ -z "$TOKEN" || "$TOKEN" = "null" ]]; then
    echo "Unable to retrieve a token to call the API"
    exit 1
fi

API_ADDRESS="https://registry-1.docker.io/v2"

declare -a HEADERS=('-H' "Accept: application/vnd.docker.distribution.manifest.v2+json" '-H' "Authorization: Bearer $TOKEN")
DIGEST=$(curl -s "${HEADERS[@]}" "${API_ADDRESS}/${IMAGE_NAME}/manifests/$TAG" | jq -r '.config.digest')

if [[ -z "$DIGEST" || "$DIGEST" = "null" ]]; then
    echo "The image '$INPUT_IMAGE' has not been found"
    exit 1
fi

CONFIG=$(curl -s -L -H "Authorization: Bearer $TOKEN" "${API_ADDRESS}/${IMAGE_NAME}/blobs/$DIGEST")
VALUE=$(jq -r ".config.Labels.$LABEL" <<< $CONFIG)

if [[ "$VALUE" = "null" ]]; then
    echo "The label '$LABEL' has not been found in the image's manifest"
    exit 1
fi

echo ::set-output name=value::"$VALUE"
