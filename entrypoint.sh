#!/usr/bin/env bash -l

IMAGE="$INPUT_IMAGE"

# Checking and parsing the input

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

# Getting the API token

TOKEN=$(curl -s "https://auth.docker.io/token?scope=repository:${IMAGE_NAME}:pull&service=registry.docker.io" | jq -r '.token')

if [[ -z "$TOKEN" || "$TOKEN" = "null" ]]; then
    echo "Unable to retrieve a token to call the API"
    exit 1
fi

# Getting all the labels

API_ADDRESS="https://registry-1.docker.io/v2"

declare -a HEADERS=('-H' "Accept: application/vnd.docker.distribution.manifest.v2+json" '-H' "Authorization: Bearer $TOKEN")
DIGEST=$(curl -s "${HEADERS[@]}" "${API_ADDRESS}/${IMAGE_NAME}/manifests/$TAG" | jq -r '.config.digest')

if [[ -z "$DIGEST" || "$DIGEST" = "null" ]]; then
    echo "The image '$IMAGE' has not been found"
    exit 1
fi

LABELS_JSON=$(curl -s -L -H "Authorization: Bearer $TOKEN" "${API_ADDRESS}/${IMAGE_NAME}/blobs/$DIGEST" | jq -r ".config.Labels")
KEYS=$(jq -r ". | keys[]" <<< $LABELS_JSON)

# Setting outputs

for KEY in $KEYS
do
    VALUE=$(jq -r ".$KEY" <<< $LABELS_JSON)
    echo ::set-output name="$KEY"::"$VALUE"
done
