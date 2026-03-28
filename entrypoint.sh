#!/usr/bin/env bash

# Configuration via environment variables
USER_NAME="${USER_NAME:-ubuntu}"
USER_PASSWORD="${USER_PASSWORD:-ubuntu}"
USER_UID="${USER_UID:-1020}"
USER_GID="${USER_GID:-1020}"

# Create the user account if it doesn't exist
if ! id "$USER_NAME" >/dev/null 2>&1; then
    # Create group
    groupadd --gid "$USER_GID" "$USER_NAME"
    # Create user with encrypted password
    useradd --shell /bin/bash \
            --uid "$USER_UID" \
            --gid "$USER_GID" \
            --groups sudo \
            --password "$(openssl passwd -1 "$USER_PASSWORD")" \
            --create-home \
            --home-dir "/home/$USER_NAME" \
            "$USER_NAME"
    echo "Created user: $USER_NAME with UID/GID: $USER_UID/$USER_GID"
else
    # Update password if user exists (in case password changed)
    echo "$USER_NAME:$USER_PASSWORD" | chpasswd
fi

# Adjust docker group GID to match the mounted socket
if [ -S /var/run/docker.sock ]; then
    DOCKER_SOCKET_GID=$(stat -c '%g' /var/run/docker.sock)
    if [ -n "$DOCKER_SOCKET_GID" ] && [ "$DOCKER_SOCKET_GID" != "0" ]; then
        if getent group docker >/dev/null 2>&1; then
            groupmod -g "$DOCKER_SOCKET_GID" docker 2>/dev/null || true
        else
            groupadd -g "$DOCKER_SOCKET_GID" docker
        fi
        usermod -aG docker "$USER_NAME"
        echo "Adjusted docker group GID to $DOCKER_SOCKET_GID"
    fi
fi

# Start Docker daemon if docker command is available
if command -v dockerd >/dev/null 2>&1; then
    echo "Starting Docker daemon..."
    dockerd &
    sleep 5
fi

# Remove existing sesman/xrdp PID files to prevent rdp sessions hanging on container restart
[ ! -f /var/run/xrdp/xrdp-sesman.pid ] || rm -f /var/run/xrdp/xrdp-sesman.pid
[ ! -f /var/run/xrdp/xrdp.pid ] || rm -f /var/run/xrdp/xrdp.pid

# Start xrdp sesman service
/usr/sbin/xrdp-sesman

# Run xrdp in foreground if no commands specified
if [ -z "$1" ]; then
    /usr/sbin/xrdp --nodaemon
else
    /usr/sbin/xrdp
    exec "$@"
fi
