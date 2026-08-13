set -e
docker build -t zodern/meteor ../image
docker build -t zodern/meteor:root ../root-image

command -v meteor >/dev/null 2>&1 || { curl https://install.meteor.com/ | sh; }

docker rm -f meteor-docker-test >/dev/null || true

sudo rm -rf /tmp/docker-meteor-tests
mkdir /tmp/docker-meteor-tests
cp -r ../ /tmp/docker-meteor-tests
cd /tmp/docker-meteor-tests/tests
TESTS_DIR="$PWD"

rm -rf ./app
rm -rf ./bundle
rm -rf ./archive
mkdir ./app
mkdir ./bundle
mkdir ./archive

# Shows output whe the command fails
hide_output () {
  file='./command_logs.txt'
  rm -f "$file" || true
  set +e
  "$@"  > "$file" 2>&1
  code=$?
  set -e
  [ "$code" -eq 0 ] || cat "$file"

  return "$code"
 }

change_version() {
  echo "=> Creating app with ${1:-"latest Meteor version"}"

  cd ..
  rm -rf app
  hide_output meteor create $1 app
  cd app

  # Remove hot-module-replacement package since it causes errors with debug builds
  sed -i -e '/hot-module-replacement/d' .meteor/packages

  sleep 1

  echo "=> npm install babel-runtime"
  NODE_TLS_REJECT_UNAUTHORIZED=0 npm_config_strict_ssl=false hide_output meteor npm install babel-runtime -q || true

  # At some point, the default app started creating Mongo collections
  # Remove the default server code so we can test without Mongo
  if [ -f ./server/main.js ]; then
    echo "" > ./server/main.js
  fi
}

build_app() {
  echo "=> Building app"
  sudo rm -rf /tmp/docker-meteor-tests/bundle || true
  meteor build ../bundle --debug
}

build_app_directory() {
  echo "=> Building app"
  meteor build --directory --debug ../bundle
}

test_bundle() {
  echo "=> Testing bundle volume"
  mv ../bundle/app.tar.gz ../bundle/bundle.tar.gz

  echo "==> Creating docker container"

  docker run \
    -v "$PWD"/../bundle:/bundle \
    -e "ROOT_URL=http://localhost.com" \
    -e "NPM_INSTALL_OPTIONS=--no-bin-links" \
    -e "NODE_TLS_REJECT_UNAUTHORIZED=0" \
    -e "npm_config_strict_ssl=false" \
    $EXTRA_DOCKER_ARGS \
    -p 3000:3000 \
    -d \
    --name meteor-docker-test \
    "$DOCKER_IMAGE"
}

test_bundle_docker() {
  echo "=> Testing bundle image"
  NODE_VERSION=$(meteor node --version)

  echo "==> Creating image"
  mv ../bundle/app.tar.gz ../bundle/bundle.tar.gz  
  cd ../bundle

  cat > Dockerfile << EOT
FROM $DOCKER_IMAGE
COPY ./bundle.tar.gz /bundle/bundle.tar.gz
EOT

  hide_output docker build --build-arg NODE_VERSION="$NODE_VERSION" -t zodern/meteor-test .
  docker run --name meteor-docker-test \
  -e "ROOT_URL=http://app.com" \
  -e "NODE_TLS_REJECT_UNAUTHORIZED=0" \
  -e "npm_config_strict_ssl=false" \
  -p 3000:3000 \
  -d \
  zodern/meteor-test

  cd ../app
}

test_built_docker() {
  echo "=> Testing built_app image"
  NODE_VERSION=$(meteor node --version)

  echo "==> Creating image"

  cd ../bundle/bundle
  cat <<EOT > Dockerfile
FROM $DOCKER_IMAGE
COPY --chown=app:app . /built_app
RUN cd /built_app/programs/server && NODE_TLS_REJECT_UNAUTHORIZED=0 npm_config_strict_ssl=false npm install $NPM_OPTIONS
EOT

  hide_output docker build --build-arg NODE_VERSION="$NODE_VERSION" -t zodern/meteor-test .
  docker run --name meteor-docker-test \
  -e "ROOT_URL=http://app.com" \
  -p 3000:3000 \
  -d \
  zodern/meteor-test

  cd ../../app
}

verify() {
  TIMEOUT=300
  elaspsed=0
  success=0

  while [[ "$elaspsed" != "$TIMEOUT" && $success == 0 ]]; do
    sleep 1
    elaspsed=$((elaspsed+1))

    curl -s \
      localhost:3000 >/dev/null \
      && success=1
            
  done

  if [ "$success" == "0" ]; then
    echo "FAIL"
    docker logs meteor-docker-test --tail 150
    exit 1
  fi

  echo "SUCCESS"
  docker rm -f meteor-docker-test >/dev/null || true
}

test_version() {
  change_version "$1"

  build_app
  test_bundle
  verify

  build_app
  test_bundle_docker
  verify

  build_app_directory
  test_built_docker "$1"
  verify
}

# UWS requires a newer glibc version. Make sure it works with the base image.
# Reuses the app created by the previous test_version call
# TODO: create new app
test_uws_transport() {
  echo "=> Testing uws DDP transport"
  build_app
  EXTRA_DOCKER_ARGS="-e DDP_TRANSPORT=uws" test_bundle
  verify
}

test_latest() {
  test_version
  test_uws_transport
}

# Docker older than 20.10.10 denies the clone3 syscall with EPERM, which stops
# node from creating threads on the Debian 13 base image. We can't fix that from
# inside the image, but we should explain it instead of letting nvm report the
# npm "prefix" option as "". clone3-eperm-seccomp.json reproduces the old
# default seccomp profile.
test_clone3_check() {
  echo "=> Checking clone3 detection"

  set +e
  output=$(docker run --rm \
    --security-opt seccomp="$TESTS_DIR/clone3-eperm-seccomp.json" \
    --entrypoint bash \
    "$DOCKER_IMAGE" /home/app/scripts/setup_nvm.sh 2>&1)
  code=$?
  set -e

  if [ "$code" -eq 0 ]; then
    echo "FAIL: expected a runtime without clone3 to be rejected"
    echo "$output"
    exit 1
  fi

  if ! echo "$output" | grep -q "20.10.10"; then
    echo "FAIL: the error did not say which Docker version is needed"
    echo "$output"
    exit 1
  fi

  echo "SUCCESS"
}

test_versions() {
  echo "--- Testing Docker Image $DOCKER_IMAGE ---"

  if [[ -z ${METEOR_TEST_OPTION+x} ]]; then
    test_version "--release=1.2.1"
    test_version "--release=1.3.5.1"
    test_version "--release=1.4.4.6"
    test_version "--release=1.5.4.1"
    test_version "--release=1.6.1.4"
    test_version "--release=1.7.0.5"
    test_version "--release=1.8.1"
    test_version "--release=1.9.3"
    test_version "--release=1.10.2"
    test_version "--release=1.11.1"
    test_version "--release=2.1.1"
    test_version "--release=2.2"
    test_version "--release=2.3.2"
    test_version "--release=2.4.1"
    test_version "--release=2.5.6"
    test_version "--release=2.6"
    test_version "--release=2.7"
    test_version "--release=2.8.0"
    test_version "--release=2.9.0"
    test_version "--release=2.10.0"
    test_version "--release=2.11.0"
    test_version "--release=2.12"
    test_version "--release=2.13.3"

    # Latest version
    test_latest
  elif [[ "$METEOR_TEST_OPTION" == "latest" ]]; then
    test_latest
  else
    test_version "$METEOR_TEST_OPTION"
  fi
}

# Needed for old Meteor versions
export NODE_TLS_REJECT_UNAUTHORIZED=0
# Fixes some Meteor versions crashing when creating a debug build 
export DISABLE_REACT_FAST_REFRESH="true"

DOCKER_IMAGE="zodern/meteor"
NPM_OPTIONS=""

if [[ -z ${METEOR_TEST_OPTION+x} || "$METEOR_TEST_OPTION" == "latest" ]]; then
  test_clone3_check
fi

test_versions

DOCKER_IMAGE="zodern/meteor:root"
NPM_OPTIONS="--unsafe-perm"

if [[ -z ${METEOR_TEST_OPTION+x} || "$METEOR_TEST_OPTION" == "latest" ]]; then
  echo "=> Checking phantomjs"
  docker run --rm --entrypoint phantomjs "$DOCKER_IMAGE" --version
fi

test_versions
