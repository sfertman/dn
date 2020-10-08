# dn
**D**ocker powered **N**ode.js version manager

## What?
A version manager for Node.js which uses docker containers for isolation.

## Why?
- I want to run and build Node.js apps in complete isolation and I don't want to explicitly invoke docker for every little thing.
- I wanted to see what it takes to build batteries-included well documented cli application in bash (this still has some way to go but I think I've done pretty well so far.)

## Getting started
- [Install Docker](https://docs.docker.com/desktop/#download-and-install)
- Clone this repo
- Install the script `./dn.sh install`
- Run `dn --help` and take it from there

## Inspiration
- [tj/n](https://github.com/tj/n)
- [jenv](https://github.com/jenv/jenv)
- Docker

## Compared with n
Whenever you switch node versions in `n`, it removes the previous version and installs the new one on your machine. `dn` does not touch your existing node installation. Instead, it pulls the official node alpine docker images and runs your commands in containers.

## Limitations
- Currently limited to whatever comes with `node:X-alpine` docker image. So, if you have a fancy build process which requires special dependencies then this manager cannot support it yet.
- Performance, especially start up, can be a bit slower since we're running in Docker.
- No terminal tab completion yet.
- Tested on Ubuntu, Mac, bash and zsh only.