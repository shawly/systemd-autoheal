# systemd Docker Autoheal Tests

Docker Compose is used to build and deploy test environment.

test.sh waits on watch-autoheal exit code.

Currently setup to a very basic exit 1 on invalid restart and exit 0 on valid restart.

## Install the systemd service

Follow the README in the main repo to install the service.

## Change AUTOHEAL_CONTAINER_LABEL

You can either change your `/etc/conf.d/docker-autoheal` file and set `AUTOHEAL_CONTAINER_LABEL=autoheal-test`.

Or set the `tests/.env` file and set `AUTOHEAL_CONTAINER_LABEL=autoheal` or run `export AUTOHEAL_CONTAINER_LABEL=autoheal`.

Otherwise the tests will have the wrong label and the script will not react! If you just want to run the script you can check below on how to run the script in a container.

## Run tests against systemd service

By default, this is for testing the systemd service itself.

```
cd tests
sudo bash tests.sh
systemctl status docker-autoheal.service
```

## Run tests against script in container

This will build a container with the `docker-entrypoint` script and run autoheal in a container.

```
cd tests
export AUTOHEAL_CONTAINER_LABEL=autoheal-docker-test
export COMPOSE_PROFILES=docker-mode
sudo bash tests.sh
```
