#!/usr/bin/env bash

# install script inspired by Schniz/fnm install script

set -e

RELEASE="latest"
OS="$(uname -s)"
GITHUB="https://github.com/shawly/systemd-autoheal"
ISSUE_URL="$GITHUB/issues"

if [ -f "/etc/os-release" ]; then
  source /etc/os-release
else
  echo "WARNING: Could not detect OS, installation will be unsupported!"
fi

# Parse Flags
parse_args() {
  while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
    -d | --install-dir)
      INSTALL_DIR="$2"
      shift
      shift
      ;;
    --local-install)
      echo "\`--local-install\`: Installing from local working directory." >&2
      LOCAL_INSTALL="true"
      shift
      ;;
    --user)
      echo "\`--user\`: Installing as user service." >&2
      USER_SERVICE="true"
      if [ "$UID" = 0 ]; then
        echo "ERROR: Installing as user service is not allowed for root!"
        exit 1
      fi
      shift
      ;;
    --uninstall)
      UNINSTALL="true"
      shift
      ;;
    -r | --release)
      RELEASE="$2"
      shift
      shift
      ;;
    *)
      echo "Unrecognized argument $key"
      exit 1
      ;;
    esac
  done

  if [ -z "$INSTALL_DIR" ]; then
    if [ "$USER_SERVICE" == "true" ] && [ -n "$XDG_DATA_HOME" ]; then
      INSTALL_DIR="$XDG_DATA_HOME/systemd-autoheal"
    elif [ "$USER_SERVICE" == "true" ]; then
      INSTALL_DIR="$HOME/.local/share/systemd-autoheal"
    else
      INSTALL_DIR="/opt/systemd-autoheal"
    fi
  fi
}

check_dependencies() {
  echo "Checking dependencies for the installation script..."

  echo -n "Checking availability of curl... "
  if hash curl 2>/dev/null; then
    echo "OK!"
  else
    echo "Missing!"
    SHOULD_EXIT="true"
  fi

  echo -n "Checking availability of unzip... "
  if hash unzip 2>/dev/null; then
    echo "OK!"
  else
    echo "Missing!"
    SHOULD_EXIT="true"
  fi

  echo -n "Checking availability of jq... "
  if hash jq 2>/dev/null; then
    echo "OK!"
  else
    echo "Missing!"
    SHOULD_EXIT="true"
  fi

  echo -n "Checking availability of docker... "
  if hash docker 2>/dev/null; then
    echo "OK!"
  else
    echo "Missing!"
    SHOULD_EXIT="true"
  fi

  if [ $UID != 0 ]; then
    echo -n "Checking availability of sudo... "
    if hash sudo 2>/dev/null; then
      echo "OK!"
    else
      echo "Missing!"
      SHOULD_EXIT="true"
    fi
  fi

  echo -n "Checking for systemd... "
  # TODO: is this the best way to check for systemd?
  if hash systemctl 2>/dev/null && [[ "$(file /sbin/init)" =~ ^.+lib\/systemd\/systemd$ ]]; then
    echo "OK!"
  else
    echo "Could not detect systemd! The installer only supports systemd, for other service managers you can install the autoheald script manually."
    echo "If this is an error and your system DOES use systemd, please report an issue to $ISSUE_URL."
    SHOULD_EXIT="true"
  fi

  if [ "$SHOULD_EXIT" = "true" ]; then
    echo "Not installing autoheal service due to missing dependencies."
    exit 1
  fi
}

_sudo() {
  # execute as sudo if we are not installing as user service or are root
  if [ "$USER_SERVICE" == "true" ] || [ "$UID" = 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

_systemctl() {
  # execute as sudo if we are not installing as user service
  if [ "$USER_SERVICE" == "true" ]; then
    systemctl --user "$@"
  else
    _sudo systemctl "$@"
  fi
}

download_autoheal() {
  FILENAME=systemd-autoheal
  if [ "$RELEASE" = "latest" ]; then
    URL="$GITHUB/releases/latest/download/$FILENAME.zip"
  else
    URL="$GITHUB/releases/download/$RELEASE/$FILENAME.zip"
  fi

  DOWNLOAD_DIR=$(mktemp -d)

  echo "Downloading $URL..."

  if ! curl --progress-bar --fail -L "$URL" -o "$DOWNLOAD_DIR/$FILENAME.zip"; then
    echo "Download failed.  Check that the release/filename are correct."
    exit 1
  fi

  unzip -q "$DOWNLOAD_DIR/$FILENAME.zip" -d "$DOWNLOAD_DIR"

  echo "Installing docker-autoheal.service..."
  copy_files $DOWNLOAD_DIR
}

local_install() {
  echo "Installing docker-autoheal.service..."
  if [ -f "docker-entrypoint" ] && [ -f "docker-autoheal.service" ]; then
    copy_files $PWD
  else
    echo "ERROR: Could not find docker-entrypoint and docker-autoheal.service in $PWD"
  fi
}

copy_files() {
  SOURCE_DIR=$1
  _sudo mkdir -p "$INSTALL_DIR"
  if [ -f "$INSTALL_DIR/docker-autoheal.service" ] || [ -f "$INSTALL_DIR/docker-entrypoint" ]; then
    echo "Detected existing installation of docker-autoheal.service, updating..."
    UPDATE_INSTALL="true"
  fi
  _sudo cp -f "$SOURCE_DIR/docker-autoheal.service" "$INSTALL_DIR/docker-autoheal.service"
  _sudo cp -f "$SOURCE_DIR/docker-entrypoint" "$INSTALL_DIR/docker-entrypoint"
  _sudo sed -i "s@<INSTALL_DIR>@$INSTALL_DIR@" "$INSTALL_DIR/docker-autoheal.service"
  _sudo chmod 755 "$INSTALL_DIR"
  _sudo chmod 755 "$INSTALL_DIR/docker-entrypoint"
}

copy_systemd_unit() {
  echo "Copying docker-autoheal.service..."
  if [ "$USER_SERVICE" == "true" ]; then
    mkdir -p "$HOME/.local/share/systemd/user"
    cp -f "$INSTALL_DIR/docker-autoheal.service" "$HOME/.local/share/systemd/user/docker-autoheal.service"
    _systemctl link "$HOME/.local/share/systemd/user/docker-autoheal.service"
  else
    _sudo cp -f "$INSTALL_DIR/docker-autoheal.service" "/usr/lib/systemd/system/docker-autoheal.service"
    _systemctl link "/usr/lib/systemd/system/docker-autoheal.service"
  fi
}

enable_systemd_service() {
  echo "Enabling docker-autoheal.service..."
  _systemctl enable docker-autoheal.service
}

start_systemd_service() {
  if [ "$UPDATE_INSTALL" != "true" ]; then
    echo "Starting docker-autoheal.service..."
    _systemctl start docker-autoheal.service
  else
    echo "Restarting docker-autoheal.service..."
    _systemctl restart docker-autoheal.service
  fi
  _systemctl status docker-autoheal.service
}

uninstall_systemd_service() {
  echo "Uninstalling docker-autoheal.service..."
  set +e
  _systemctl disable docker-autoheal.service
  _systemctl stop docker-autoheal.service
  if [ "$USER_SERVICE" == "true" ]; then
    rm -r "$INSTALL_DIR"
    rm "$HOME/.local/share/systemd/user/docker-autoheal.service"
  else
    _sudo rm -r "$INSTALL_DIR"
    _sudo rm "/usr/lib/systemd/system/docker-autoheal.service"
  fi
  _systemctl daemon-reload
  echo "Uninstalled docker-autoheal.service!"
  set -e
}

parse_args "$@"
if [ "$UNINSTALL" == "true" ]; then
  uninstall_systemd_service
  exit 0
fi

check_dependencies
if [ "$LOCAL_INSTALL" == "true" ]; then
  local_install
else
  download_autoheal
fi
copy_systemd_unit
enable_systemd_service
start_systemd_service

exit 0
