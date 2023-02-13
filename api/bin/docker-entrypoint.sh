#!/bin/sh
set -e

# https://bundler.io/guides/bundler_docker_guide.html
unset BUNDLE_PATH
unset BUNDLE_BIN

if [ -f tmp/pids/server.pid ]; then
  echo "Cleanup service.pid"
  rm tmp/pids/server.pid
fi
bundle install
exec bundle exec "$@"
