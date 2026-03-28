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
