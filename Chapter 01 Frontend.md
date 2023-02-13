# React Frontend

Starting with frontend.

## Initial setup

Need to set things up for ownership using the UID and GID variables.

1. Dockerfile

```Dockerfile
# https://hub.docker.com/_/node/
FROM node:18.14.0-bullseye

ARG UID=1000
ARG GID=1000

EXPOSE 3000

USER "${UID}:${GID}"
```

2. docker-compose.yml

```yml
version: "3.8"
services:
  frontend:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        - "UID=${UID:-1000}"
        - "GID=${GID:-1000}"
    restart: "no"
    volumes:
      - ./frontend:/app
```

3. bin/run

```bash
#!/bin/bash
USERID=( `id -u` )
GROUPID=( `id -g` )
docker compose run --user "$USERID:$GROUPID" --env UID="$USERID" --env GID="$GROUPID" frontend yarn create react-app app --template typescript
```

Execute these commands:

```sh
chmod +x bin/run
mkdir frontend
bin/run
```

Its important to create the `frontend` folder before running the script, otherwise the folder might get created as `root`.

Everything should run correctly, except for one final error:

```
Git commit not created Error: Command failed: git commit -m "Initialize project using Create React App"
```

This fails because `git` isn't installed on the Node Docker image. We're using `git` from the host thorugh so this isn't a problem.

You should have a React application created in the `frontend` folder now.

## Setup frontend

Move `Dockerfile` into the `frontend` folder

```sh
mv Dockerfile frontend
```

fix docker-compose.yml

```yml
version: "3.8"
services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
      args:
        - "UID=${UID:-1000}"
        - "GID=${GID:-1000}"
    restart: "no"
    volumes:
      - ./frontend:/app
```

bin/run
```bash
#!/bin/bash
USERID=( `id -u` )
GROUPID=( `id -g` )
docker compose exec --user "$USERID:$GROUPID" --env UID="$USERID" --env GID="$GROUPID" $@
```

## Setup ENTRYPOINT

Use an entrypoint so that Docker runs and stops cleanly.

1. frontend/bin/docker-entrypoint.sh

```sh
#!/bin/sh
set -e

yarn install
exec $@
```

```sh
chmod +x frontend/bin/docker-entrypoint.sh
```

2. frontend/Dockerfile

```Dockerfile
# https://hub.docker.com/_/node/
FROM node:18.14.0-bullseye

ARG UID=1000
ARG GID=1000

EXPOSE 3000

USER "${UID}:${GID}"

WORKDIR /app

ENTRYPOINT ["/app/bin/docker-entrypoint.sh"]
CMD ["yarn", "start"]
```

3. docker-compose.yml

```yml
version: "3.8"
services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    command: ["yarn", "start"]
    user: "${UID}:${GID}"
    restart: "no"
    volumes:
      - ./frontend:/app
    ports:
      - "3000:3000"
```

## Create .env file for common ENV variables

This makes starting and stopping Docker with Compose easy. Docker will detect and load the file automatically.

```env
# Host configuration
TZ=America/Denver

# User info so that generated files are owned by you, not root
UID=1000 # id -u
GID=1000 # id -g
```

**NOTE** Set the UID and GUID values based on the result of running `id -u` and `id -g` respectively. Then file ownership will belong to your user.
I set TZ based on my local TZ, but it isn't necessary.
