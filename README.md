# `dn` - **D**ocker powered **N**ode.js version manager

## Getting started
1. [Install Docker](https://docs.docker.com/desktop/#download-and-install)
1. Download and install [latest release](https://github.com/sfertman/dn/releases/latest):

    ```
    wget https://github.com/sfertman/dn/releases/latest/download/dn.sh
    chmod +x dn.sh
    ./dn.sh install
    ```
    
1. Start using the version of node you want, e.g.:

    ```
    dn 6.14
    ```
    
1. Learn more:

    ```
    dn --help
    ```

## Why does it exist?
- I need to make sure my apps work with multiple versions of Node.js
- I need to reproducibly build, test and run Node.js apps. Docker is a great solution for deployment but I don't want to deal with dockerfiles and docker-compose in my day to day.
- I wanted to see what it takes to build a "batteries included", well documented cli application in bash (this still has some way to go but I think I've done pretty well so far.)

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
