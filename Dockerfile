FROM leifcr/alpine-curl-jq:latest

COPY entrypoint.sh /entrypoint.sh

CMD ["/bin/bash", "/entrypoint.sh"]
