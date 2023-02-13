# https://hub.docker.com/_/node/
FROM node:18.14.0-bullseye

ARG UID=1000
ARG GID=1000

EXPOSE 3000

USER "${UID}:${GID}"

WORKDIR /app

ENTRYPOINT ["/app/bin/docker-entrypoint.sh"]
CMD ["yarn", "start"]
