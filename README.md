# Dockerized Rails and React Example

This is an example of a Dockerized application development environment for React running in parallel with a Ruby on Rails back-end. This is a development environment only, **not** an example of a production environment (see the FAQ for details).

This is a demonstration of how to create and setup a common developer environment for different programming languages without having to install those languages on your computer. Everything is provided by Docker containers.

In this document I'll walk you step-by-step through how to setup a Docker Compose file to create your React and Rails applications using only Docker. No installation of Ruby or Node on your host machine will be required.

**Requirements:**

To follow the directions you need to have the following installed:

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed (I won't walk you through installing Docker,
[the Docker website](https://www.docker.com/get-started/) has the directions you'll need for your OS)
- [Visual Studio Code](https://code.visualstudio.com/) or another IDE or text editor (including vim or emacs)

There are some subtle differences with how Docker works on Windows, MacOS and Linux. I'll try to point out extra steps necessary depending on your OS version whenever necessary. Docker makes it possible to create common developer environments without having to depend on the host operating system! On Windows however I *strongly* recommend using the [WSL/WSL2 integration](https://docs.docker.com/desktop/windows/wsl/) for managing and interacting with Docker.

## Getting Started

Docker containers can be created and run from the command-line quite easily but we're going to be running an entire environment. To manage multiple containers for a single application we can use a Docker feature called [Docker Compose](https://docs.docker.com/compose/). Docker Compose makes it much easier to manage multiple containers and the mapping of folders and also the networking between containers.

Docker Compose is managed through a [YAML](https://yaml.org/) file called `docker-compose.yml`. So lets begin with that.

### Step 1: Create a docker-compose.yml file

In the directory you'll be working in create a file called `docker-compose.yml` and fill it with the following:

```yml
services:
  frontend:
    image: node:18.8.0-bullseye
    restart: "no"
    volumes:
      - ./frontend:/app
```

In this file we have described one container named `frontend` that will be running Node v18 on Debian Bullseye. It won't restart. It maps a folder "volume" from the `/app` folder on the container to `./frontend` from the working folder on the host machine.

Now we can use `create-react-app` to create our frontend React framework by running a command **on the container** and the volume mapping will save the files to our host machine:


```sh
docker compose run frontend yarn create react-app app --template typescript
```

**A few things are going to happen now!**

1. Docker will download the Node 18 image layers from Docker Hub to your host computer.
2. Docker Compose will start a container named "frontend" using the image it just downloaded with the folder mapping `/frontend` to `/app`
3. Docker will *run* on "frontend" the `yarn create react-app` command into the `/app` folder on the container using the Typescript template.
4. Because Docker mapped `/app` to `./frontend` Docker will create the `frontend` folder and when `create-react-app` finishes the React application will also be in that folder on the host machine.
5. When `create-react-app` completes Docker will stop the "frontend" container.

All of these steps took a little over 10 minutes on my computer so don't be worried if it takes a while. This did not install Node on your host machine, it ran it from inside a Docker container.

### Step 2: Create a Docker Image for Frontend

In the newly created `frontend` folder we need to create a `Dockerfile` that will let us create the React frontend over-and-over and to run the app when we start the app.

Create `Dockerfile` in the `frontend` folder. Put the following contents in:

```Dockerfile
FROM node:18.8.0-bullseye

RUN mkdir /app
WORKDIR /app

EXPOSE 3000
```

The `Dockerfile` will use the same `image` we used from the `docker-compose` file (node:18.8.0-bullseye) as a base, but will use `/app` for the directory to run commands in. It also will `EXPOSE` port 3000, the default for the `create-react-app` server.

Now lets edit the `docker-compose.yml` file so that it will use the `Dockerfile` to create the app image instead of the raw Node:18-bullseye image:

```yml
version: "3.8"
services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    command: yarn install && yarn start
    restart: "no"
    volumes:
      - ./frontend:/app
    ports:
      - "3000:3000"

```

So by replacing the `image` section with a `build` section we've changed "frontend" from using an `image` to a built Dockerfile.

We've also added a `command` that will run `yarn install` then `yarn start` starting the React development server.

Now we can start the React server now using the following command:

```sh
docker compose up
```

After the React server is running you will be able to use your web browser to go to http://localhost:3000/ and you should see the Create React App default page.

At this point we have demonstrated how to use Docker to create a Node/React application without having to install any programming languages. How exciting! 🥳 You can fire up your code editor to edit directly from the host filesystem or open in the container using VS Code devcontainers or WebStorm.

> A note about Windows and Live Reload: The Windows filesystem does not support the background notifications that the Linux and MacOS filesystems do in Docker. As a result file watchers like React uses do no work if you're starting your Docker containers from Windows. This is a huge bummer for me and maybe for you too.
>
> The best workaround I can offer right now is to start your Docker containers from a WSL distribution. Since Docker uses its own WSL distro for its services you should have all the prerequisites required to install Ubuntu or another WSL distro right from the Windows Store.

Before we go to the next step lets stop our current Docker services:

```sh
docker compose down
```

## Step 3: Create the Rails Backend

Now we are going to build on our working frontend to add our backend service.

To make it a little more challenging we'll create our Rails application to use Postgres and Redis. This will make it closer to what you'd likely run in production but more importantly it will show just how easy it is to add services using Docker Compose!

I'll start with the easy part: the Postgres and Redis services. These are database services and they'll have data we need to keep around after we do things like restart our computers. That means we'll need persistent volumes for them.

### Step 3a: Add Postgres and Redis services

Lets add the following snippet to our `docker-compose.yml` file:

```yml
version: "3.8"
services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    command: yarn install && yarn start
    restart: "no"
    volumes:
      - ./frontend:/app
    ports:
      - "3000:3000"
  postgres:
    image: postgres:12.11-alpine
    environment:
      POSTGRES_PASSWORD: _Password123!
    volumes:
      - postgres-data:/var/lib/postgresql/data:rw
  redis:
    image: redis:7.0-alpine
    volumes:
      - redis-data:/data:rw
volumes:
  postgres-data:
  redis-data:

```

You'll note that we've added the `volume` mapping for the databases. Docker always uses the notation of `host:container`. In this example we're creating two *Docker managed volumes* called `postgres-data` and `redis-data` in the `volumes` section. In the frontend section we wanted to map the sourcecode to a folder. For the database services we're not as worried about where the data should go so we'll let Docker create manage the volumes on its own.

You've probably also noticed the `environment` section for the `postgres` service. In keeping with the [12 Factor App](https://12factor.net/config) both Docker and Postgres allow passing configuration settings through environment variables. The [Postgres Docker image requires we create a database with a password](https://hub.docker.com/_/postgres/) and that is done with the `POSTGRES_PASSWORD` environment variable.

> Right now `POSTGRES_PASSWORD` is not a safe or secure password, even for a development environment. I'll show you how to configure it better soon.

To test the setting lets start Docker again:

```sh
docker compose up
```

This may take a little while again as Docker pulls images for Postgres and Redis from the Docker Hub. You will know things are ready when you see in the console output:


```
docker-rails-react-postgres-1  | 2022-01-01 00:00:00.000 UTC [1] LOG:  database system is ready to accept connections
```

and

```
docker-rails-react-redis-1     | 1:M 01 Jan 2022 00:00:00.000 * Ready to accept connections
```

If both services are "ready to accept connections" we are ready to proceed with setting up Rails. Use `CTRL-C` to stop docker and run `docker compose down` to stop the services again.

### Step 3b: Add the Rails Backend service

The first thing we need to do would be to create a container for our backend Rails service. We'll do the same thing we did for the `frontend` service and use a `Dockerfile` and build context.

Run the following commands to create an `api` folder and `Dockerfile`:

```sh
mkdir api
touch api/Dockerfile
```

Now lets edit the `api/Dockerfile` to use the latest Ruby 3.1 image:

```Dockerfile
FROM ruby:3.1-bullseye

RUN gem install bundler rails rake

RUN mkdir /app
ENV RAILS_ROOT /app
WORKDIR /app

EXPOSE 3000
```

Now add a new service to your `docker-compose.yml` file:
```yml
services:
  # Other services omitted
  api:
    build:
      context: ./api
      dockerfile: Dockerfile
    command: sh -c "/wait && bin/start_rails.sh"
    restart: "no"
    volumes:
      # Persist (and share) Bundler data
      - ./api:/app
```
We've added a volume mapping `api` to `app` in the container. Now lets use this container to create a new Rails app:

```sh
docker compose run api rails new . --database=postgresql --api --skip-git
```

This will kick off the following steps:
1. Docker will pull the latest Ruby 3.1 image
1. Docker Compose will start the services
1. When all of the services are up it will create a new Rails app in the container.

Thanks to the volume mapping your new Rails app will be created in the `api` folder. Have a look.

### Step 3c: Configure Rails to use other services

Rails of course takes a little bit of setup to use the services we've created. The settings are easy to add using [environment variables](https://docs.docker.com/compose/environment-variables/). We already added one environment variable setting `POSTGRES_PASSWORD` above. To make maintaining the configuration easier, as well as to make it shareable among containers lets move our configuration into a [separate file called `.env`](https://docs.docker.com/compose/environment-variables/#the-env-file).

So create `.env` at the same level as your `docker-compose.yml` file and add the following to it:

```env
POSTGRES_HOST=postgres
POSTGRES_PORT=6120
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=noosphere
DATABASE_URL=postgres://postgres:postgres@postgres:6120/noosphere

REDIS_HOST=redis
REDIS_PORT=6379
REDIS_CHANNEL_PREFIX=noosphere
REDIS_URL=redis://redis:6379/0
```

#### Edit database.yml

Lets setup Rails to use the database. Edit `api/config/database.yml` to have the following contents:

```yml
default: &default
  adapter: postgresql
  encoding: unicode
  # For details on connection pooling, see Rails configuration guide
  # https://guides.rubyonrails.org/configuring.html#database-pooling
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  username: <%= ENV['POSTGRES_USER'] %>
  password: <%= ENV['POSTGRES_PASSWORD'] %>
  host: <%= ENV['POSTGRES_HOST'] %>
  port: <%= ENV['POSTGRES_PORT'] %>

development:
  <<: *default
  database: <%= ENV['POSTGRES_DB'] %>

test:
  <<: *default
  database: <%= ENV['POSTGRES_DB'] %>_test

production:
  <<: *default
  database: <%= ENV['POSTGRES_DB'] %>
```

#### Edit cable.yml

We can setup ActionCable to use our Docker Redis instance in development too. Edit `api/config/cable.yml` to have to have the following contents:

```yml
development:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://redis:6379/0" } %>
  channel_prefix: <%= ENV.fetch("REDIS_CHANNEL_PREFIX") { "" } %>

test:
  adapter: test

production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://redis:6379/0" } %>
  channel_prefix: <%= ENV.fetch("REDIS_CHANNEL_PREFIX") { "" } %>
```

#### Edit Docker Compose

Now to use it we can add `env_file` to all of the services and remove the `environment` section in our `docker-compose.yml` file:

```yml
version: "3.8"
services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    command: yarn install && yarn start
    restart: "no"
    env_file: # new
      - ".env"
    volumes:
      - ./frontend:/app
    ports:
      - "3000:3000"
  api:
    build:
      context: ./api
      dockerfile: Dockerfile
    command: sh -c "bundle install && bin/rails server"
    restart: "no"
    env_file: # new
      - ".env"
    volumes:
      - ./api:/app
  postgres:
    image: postgres:12.11-alpine
    env_file: # new
      - ".env"
    volumes:
      - postgres-data:/var/lib/postgresql/data:rw
  redis:
    image: redis:7.0-alpine
    env_file: # new
      - ".env"
    volumes:
      - redis-data:/data:rw
volumes:
  postgres-data:
  redis-data:
```

### Fixing the server.pid Problem

When I run `docker compose up` a second time I got the following output:

```
docker-rails-react-api-1       | => Booting Puma
docker-rails-react-api-1       | => Rails 7.0.4 application starting in development
docker-rails-react-api-1       | => Run `bin/rails server --help` for more startup options
docker-rails-react-api-1       | Exiting
docker-rails-react-api-1       | A server is already running. Check /app/tmp/pids/server.pid.
```

An accidental result of running the Rails server through `sh -c` like we did in our `docker-compose.yml` file is that `sh` will catch but not pass interrupt signals through to Rails. Without that signal the [Puma](https://puma.io/) webserver isn't able to shutdown cleanly and erase the `server.pid` file.

The [explanation and solution I was able to find via Stack Overflow](https://stackoverflow.com/a/38732187) suggests creating a Docker [entrypoint](https://docs.docker.com/engine/reference/builder/#entrypoint).

Using the `entrypoint` method requires three steps:

1. Create an entrypoint shell file (`api/bin/docker-entrypoint.sh`)
1. Add an `ENTRYPOINT` instruction to `api/Dockerfile` pointed to the shell file
1. Change the command in `docker-compose.yml` to only run `rails server`

#### Step 1: api/bin/docker-entrypoint.sh

This file checks for and removes `server.pid` then does the other environment setup commands like `bundle install`. The final line will `exec` the `command` from `docker-compose.yml`.

I put it in the `bin` subfolder as a convention but there is no reason it has to be there.

```sh
#!/bin/sh
set -e

if [ -f tmp/pids/server.pid ]; then
  rm tmp/pids/server.pid
fi
bundle install
exec bundle exec "$@"
```

#### Step 2: api/Dockerfile

The main changes to the Dockerfile are at the bottom where the ENTRYPOINT is defined

```Dockerfile
FROM ruby:3.1.3-bullseye

RUN gem install bundler rails rake

RUN mkdir /app
ENV RAILS_ROOT /app
WORKDIR /app

EXPOSE 3000

ENTRYPOINT ["/app/bin/docker-entrypoint.sh"]
CMD ["rails", "server"]
```

I'm not sure I need to have the `CMD` instruction, but it is good to provide it as a default anyways.

#### Step 3. docker-compose.yml

For brevity I'm omitting the rest of the file so you can see the change to be made:

```yml
  api:
    build:
      context: ./api
      dockerfile: Dockerfile
    command: ["rails", "server"]
```

## Step 4: Reverse Proxy

The reverse proxy will stand up in front of the React and Rails containers so that they'll be accessible through a single URL (host and port) instead of two.

We will use [nginx](https://nginx.org/en/) as our reverse proxy because it is easy to configure and provision (its also a pretty commonly used web server and proxy in production environments as well).

We will proxy the React `frontend` service to `/`, the root of our site, and, the Rails `api` to `/api` of the site. We'll also need to keep in mind that `create-react-app` provides hot reloading via a websocket at `/ws`.

I will also remove the port mapping to `frontend` and `api` so that they can only be accessed via `proxy` afterwards.

### Adding nginx

We'll be able use the [`nginx`](https://hub.docker.com/_/nginx/) Docker image directly with no need for another `Dockerfile`.

Nginx is configured using a file called `nginx.conf`. The image makes it easy to override the default configuration by merely mapping a file volume over the top of the file in the image. I'll show how to do that in the following steps:

#### Add `nginx.conf`

I'm going to create a `proxy` folder at the root, the same level as `api` and `frontend`. I'll put `nginx.conf` in there.

Create `proxy/nginx.conf` and put the following in the file:

```nginx
worker_processes auto;
worker_rlimit_nofile 2048;

events {
  worker_connections 1024;
}

error_log /dev/stdout info;

http {
  charset                utf-8;

  sendfile               on;
  tcp_nopush             on;
  tcp_nodelay            on;

  server_tokens          off;

  types_hash_max_size    2048;
  types_hash_bucket_size 64;

  client_max_body_size   64M;

  include /etc/nginx/mime.types;
  default_type           application/octet-stream;

  server {
      listen 80;

      location / {
        proxy_pass http://frontend:3000/;
        # To proxy websockets
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
      }

      # Websocket for automatic reloading
      location /ws {
        proxy_pass http://frontend:3000/ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
      }


      location /api/ {
        proxy_pass http://api:3000/;
        proxy_set_header Upgrade \$http_upgrade;
      }
  }
}
```

A lot of the file is boilerplate I copied from another file, the important changes are the `server` and `location` directives. You can see each `location` that has a `proxy_pass` directing traffic to each services from our `docker-config.yml` file. There are headers added for connection upgrades to delegate to a websocket behind the scenes too.

#### docker-compose.yml changes

I created a new service called `proxy`:
1. using the `nginx` image
2. mapping `nginx.conf` using the `volumes` command
3. setting the listening port to `3000`
4. creating dependencies on the downstream `frontend` and `api` containers so it doesn't start prematurely

```yml
  proxy:
    image: nginx:1.23.3-alpine
    volumes:
      - ./proxy/nginx.conf:/etc/nginx/nginx.conf:ro
    ports:
      - "3000:80"
    depends_on:
      - frontend
      - api
```

---

## FAQ

### Why no example of a production environment?

It is easy to use Docker in production using lots of cloud servers or your own
local computers! You'll make different choices about databases and edge servers
than we do for development. Also there will be different choices for how you
would handle things like secrets managements, cloud databases, etc.

This example is for getting a development team up, and collaborating fast!
