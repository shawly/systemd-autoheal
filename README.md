# systemd Docker Autoheal Service

![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/shawly/systemd-docker-autoheal/release.yml) ![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/shawly/systemd-docker-autoheal) ![GitHub all releases](https://img.shields.io/github/downloads/shawly/systemd-docker-autoheal/total)

Monitor and restart unhealthy docker containers, but with systemd!

This functionality was proposed to be included with the addition of `HEALTHCHECK`, however didn't make the cut.
This systemd service is a stand-in till there is native support for `--exit-on-unhealthy` https://github.com/docker/docker/pull/22719.

This is a systemd service that uses the script from [willfarrell/docker-autoheal](https://github.com/willfarrell/docker-autoheal), but with an installation script to make things as easy as using docker run or compose.

## Archived

No time and patience for maintaining bash scripts, sorry.

## Why use systemd over a Docker image?

The main reason to use systemd over a Docker image is that you don't need to expose your `docker.socket` to any container, essentially giving a container access to **all** your other containers.

In the past, Docker Hub accounts have been compromised to inject harmful software (like cryptominers) into popular images. Something like this happening to images that get direct access to the `docker.socket` would be fatal for users, as attackers can basically do anything to their victims hosts.

Using `containrrr/watchtower` in conjunction with images that use the `docker.socket`, can and probably will inevitably lead to comprimsation. Therefore keeping the amount of images with access to it to a bare minimum or better **none** is preferrable.

While a systemd unit with root access basically has the same power to compromise a system, users still have more control and transparency over what they are installing than using a Docker image. Though this is a subject to debate since users still might install scripts that can lead to their demise.

**Therefore, always check third party software before installing! You have been warned.**

In the end, it is your responsibility to keep your system safe and how many risks you want to take. But keeping your system away from third party images that use the `docker.socket` is subjectively **the best** decision.

## Installation

### Using a script

For `bash`, `zsh` and `fish` shells, there's an [automatic installation script](./install).

First ensure that `curl`, `jq` and `unzip` are already installed on you operating system. Then execute:

```sh
curl -fsSL https://shawly.github.io/systemd-docker-autoheal/install | bash
```

#### Upgrade

Upgrading `systemd-docker-autoheal` is almost the same as installing it.

#### Parameters

`--install-dir`

Set a custom directory for the service files to be installed. The default is `/opt/systemd-docker-autoheal`.

`--uninstall`

Removes the script and service from your system.

`--local-install`

Installs the files from the current working directory, this should only be used when using the manual installation methods.

`--user`

Installs the service as a user service, this can be used in conjunction with rootless Docker config.

`--release`

Installs a specific release.

Example:

```sh
curl -fsSL https://shawly.github.io/systemd-docker-autoheal/install | bash -s -- --install-dir "/usr/local/share/systemd-docker-autoheal"
```

#### Manually

##### Using git and the installer

```bash
git clone https://github.com/shawly/systemd-docker-autoheal
cd systemd-docker-autoheal
bash install --local-install
```

##### Using git without the installer

```bash
INSTALL_DIR=/opt/systemd-docker-autoheal
git clone https://github.com/shawly/systemd-docker-autoheal "$INSTALL_DIR"
sed -i "s@<INSTALL_DIR>@$INSTALL_DIR@" "$INSTALL_DIR/docker-autoheal.service"
sudo systemctl link "$INSTALL_DIR/docker-autoheal.service"
sudo systemctl enable docker-autoheal.service
sudo systemctl start docker-autoheal.service
```

If you ever disable the `docker-autoheal.service` you need to run `systemctl link $INSTALL_DIR/docker-autoheal.service` again!

Another solution would be to copy `docker-autoheal.service` to `/etc/systemd/system/` or `/usr/lib/systemd/system/`, that way the service will not be unlinked when disabled.

##### Using docker

So you still want to use this script within a container? Well, it's your choice!

You need to build the image yourself though, since I won't provide an image. I will never provide an image for applications that use the `docker.socket` so don't ask.

```
git clone https://github.com/shawly/systemd-docker-autoheal
cd systemd-docker-autoheal
sudo docker build -t shawly/autoheal:local .
sudo docker run -d
    --name autoheal \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    shawly/autoheal:local
```

## Usage

### Configuration

If you need to customize variables, you need to create the file `/etc/conf.d/docker-autoheal` which contains the variables you want to change.
The systemd unit will load its variables from that file, if it is not present, it will use the defaults from `docker-entrypoint`.

#### Default environment variables

```
AUTOHEAL_CONTAINER_LABEL=autoheal
AUTOHEAL_INTERVAL=5                # check every 5 seconds
AUTOHEAL_START_PERIOD=5            # wait 0 seconds before first health check
AUTOHEAL_DEFAULT_STOP_TIMEOUT=10   # Docker waits max 10 seconds (the Docker default) for a container to stop before killing during restarts (container overridable via label, see below)
DOCKER_SOCK=/var/run/docker.sock   # Unix socket for curl requests to Docker API
CURL_TIMEOUT=30                    # --max-time seconds for curl requests to Docker API
WEBHOOK_URL=""                     # post message to the webhook if a container was restarted (or restart failed)
CERT_PATH=/certs                   # path to your certificates if you use TCP socket
```

### UNIX socket passthrough for rootless setup

```console
$ sudo -e /etc/conf.d/docker-autoheal

DOCKER_SOCK=$XDG_RUNTIME_DIR/docker.sock
```

### TCP socket

```console
$ sudo -e /etc/conf.d/docker-autoheal

DOCKER_SOCK=tcp://HOST:PORT
CERT_PATH=/path/to/certs
```

#### Certificates

See https://docs.docker.com/engine/security/https/ for how to configure TCP with mTLS

The certificates, and keys need these names:

- ca.pem
- client-cert.pem
- client-key.pem

### Manage containers

You have several options to let your containers be managed through autoheal:

a) Apply the label `autoheal=true` to your container to have it watched.

b) Set ENV `AUTOHEAL_CONTAINER_LABEL=all` to watch all running containers.

c) Set ENV `AUTOHEAL_CONTAINER_LABEL` to existing label name that has the value `true`.

Note: You must apply `HEALTHCHECK` to your docker images first. See https://docs.docker.com/engine/reference/builder/#healthcheck for details.

### Optional Container Labels

```
autoheal.stop.timeout=20        # Per containers override for stop timeout seconds during restart
```

## Testing

Check the [documentation](./tests/README.md) in the tests folder.

## Known issues

If your current user belongs to the `docker` group, the service cannot manage containers started with `docker-compose` that were spawned by your user.
Therefore you need to start your stacks as `root` user (e.g. with `sudo`).

It is not recommended to add your user to the `docker` group anyway as it is insecure.  
So if you want to use `systemd-docker-autoheal` because of security concerns, start by removing your user from the `docker` group! Or use [docker rootless](https://docs.docker.com/engine/security/rootless/), your choice.
