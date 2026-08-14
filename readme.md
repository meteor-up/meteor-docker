zodern/meteor Docker Image
===

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/zodern/meteor-docker/test-publish.yaml?branch-master&style=flat-square) [![Docker Pulls](https://img.shields.io/docker/pulls/zodern/meteor?style=flat-square)](https://hub.docker.com/r/zodern/meteor)

Docker image to run Meteor apps.

### Features

- One image supports every Meteor version (tested with 1.2 - 3.5)
- Automatically uses correct node and npm version
- Runs app as non-root user
- Compatible with Meteor up

## Tags

- `zodern/meteor` The recommended version. Runs the app as a non-root user.
- `zodern/meteor:root` Compatible with meteord. Runs the app as the root user and has phantomjs installed. Any notes below about permissions do not apply to this image.
- `zodern/meteor:<major>` or `zodern/meteor:<major>-root` (for example, `zodern/meteor:1`) Use the latest minor or patch version, without any breaking changes from a new major version (such as changing to a newer Debian base image).
- `zodern/meteor:slim` Coming soon. Is a smaller image without node or npm pre-installed. During ONBUILD or when starting the app, it will install the correct version.

### Breaking changes in v1

Version 1 changed the base image from Debian 11 (bullseye) to Debian 13 (trixie). This is needed to support the uws DDP transport in Meteor 3.5. Old Meteor versions are still compatible. If the new base image causes problems for your app, you can use `zodern/meteor:0` or `zodern/meteor:0-root`.

Version 1 needs Docker 20.10.10 or newer, due to changes in Debian 13. Use `zodern/meteor:0` if you can not update Docker. Using an older version of Docker can result in `node[122]: pthread_create: Operation not permitted. nvm is not compatible with the npm config "prefix" option: currently set to "" `


## How To Use

### Permissions

This image runs the app with the `app` user. The owner of any files or folders your app uses inside the Docker container should be changed to `app`.

### Meteor Up

In your mup config, change `app.docker.image` to `zodern/meteor`.

If you want to use mup's `buildInstructions` option to run commands as root, you can do so by temporarily changing the user:

```
buildInstructions: [
  'USER root',
  'RUN apt-get update && apt-get install -y imagemagick graphicsmagick',
  'USER app'
]
```

### Compressed bundle

You can create the bundle with the `meteor build` command. The bundle should be available in the container at `/bundle/bundle.tar.gz`.

#### Dockerfile

Create a file named `Dockerfile` and add the following:

```Dockerfile
FROM zodern/meteor
COPY --chown=app:app ../path/to/bundle.tar.gz /bundle/bundle.tar.gz
```

Then build and run the image with

```bash
docker build --build-arg EXACT_NODE_VERSION=<true || false> --build-arg NODE_VERSION=<node version> -t meteor-app .
docker run --env NODE_VERSION=<node version> --env EXACT_NODE_VERSION=<true || false> --name my-meteor-app meteor-app
```

And your app will be running on port 3000

The `(--build-arg || --env) NODE_VERSION=<node version>` is optional, and only needed if a command in your docker file will use a specific node or npm version.

If any Node versions in `image/setup/versions.json` match the same major version of Node your app needs, the version in `versions.json` is used instead since it will have additional security fixes missing in the version Meteor specifies. If there is no matching major version, it will use the exact version Meteor specifies. To always use the exact version, you can use set `(--build-arg || --env) EXACT_NODE_VERSION=true`

#### Volume

Run

```bash
  docker run --name my-meteor-app -v /path/to/folder/with/bundle:/bundle -p 3000:3000 -e "ROOT_URL=http://app.com" zodern/meteor
```

### Built app

`Built app` refers to an uncompressed bundle that already has had it's npm dependencies installed.

When using a compressed bundle, the bundle is decompressed and the app's npm dependencies are installed every time the app is started, which can take a while. By using this method instead, both steps are done before the container is started, allowing it to start much faster. Meteor up's `Prepare Bundle` feature uses this.

Before following the instructions in either of the next two sections, build your app with `meteor build --directory ../path/to/put/bundle`.

The bundle should be available in the container at `/built_app`.

#### Docker Image

Create a file named `Dockerfile` and copy the following into it:

```Dockerfile
FROM zodern/meteor
COPY --chown=app:app ./path/to/bundle /built_app
RUN cd /built_app/programs/server && npm install
```

Then build and run your image with:

```bash
docker build -t meteor-app --build-arg NODE_VERSION="node version" .
docker run --name my-meteor-app -p 3000:3000 -e "ROOT_URL=http://app.com" meteor-app
```

#### Volume

If possible, you should create a docker image as described in the previous instructions since it is more reliable.

First, make sure you have the correct version of node installed for the Meteor version your app uses, and then run

```bash
cd /path/to/bundle
cd programs/server
npm install
```

Next, start the docker container with

```bash
docker run --name my-meteor-app -v /path/to/bundle:/built_app -p 3000:3000 -e "ROOT_URL=http://app.com" zodern/meteor
```

### Options

#### NPM_INSTALL_OPTIONS

When using a compressed bundle, you can specify the arguments used when running `npm install` by setting the environment variable `NPM_INSTALL_OPTIONS`.

## Contributing

Tests can be run with `npm test`. The tests can not be run on Windows, though WSL does work. Docker should be installed before running the tests.

Commit messages should start with one of these to allow the changelog and version to be updated correctly:

- `fix:` fixes a bug
- `feat:` adds a feature
- `perf:`
- `docs:`
- `chore:` 
- `ci:`

If the change is a breaking change, add `BREAKING CHANGE:` to the commit description
