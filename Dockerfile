# Build xrdp pulseaudio modules in builder container
# See https://github.com/neutrinolabs/pulseaudio-module-xrdp/wiki/README
ARG TAG=noble
FROM ubuntu:$TAG AS builder

RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
        autoconf \
        build-essential \
        ca-certificates \
        dpkg-dev \
        libpulse-dev \
        lsb-release \
        git \
        libtool \
        libltdl-dev \
        sudo && \
    rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git /pulseaudio-module-xrdp
WORKDIR /pulseaudio-module-xrdp
RUN scripts/install_pulseaudio_sources_apt.sh && \
    ./bootstrap && \
    ./configure PULSE_DIR=$HOME/pulseaudio.src && \
    make && \
    make install DESTDIR=/tmp/install


# Build the final image
FROM ubuntu:$TAG

RUN apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends \
        build-essential \
        clang \
        cmake \
        curl \
        dbus-x11 \
        git \
        nano \
        locales \
        pavucontrol \
        pulseaudio \
        pulseaudio-utils \
        python3 \
        python-is-python3 \
        python3-venv \
        software-properties-common \
        sudo \
        vim \
        x11-xserver-utils \
        xfce4 \
        xfce4-goodies \
        xfce4-pulseaudio-plugin \
        xorgxrdp \
        xrdp \
        xubuntu-icon-theme && \
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    npm install -g opencode-ai && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    (type -p wget >/dev/null || (apt update && apt install wget -y)) && \
    mkdir -p -m 755 /etc/apt/keyrings && \
    out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg && \
    cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    mkdir -p -m 755 /etc/apt/sources.list.d && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt update && \
    apt install gh -y && \
    apt-get install -y ca-certificates curl gnupg && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && \
    wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y dotnet-sdk-10.0 && \
    apt-get install -y -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev && \
    wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.29.0-stable.tar.xz -O /tmp/flutter.tar.xz && \
    tar xf /tmp/flutter.tar.xz -C /opt && \
    rm /tmp/flutter.tar.xz && \
    ln -s /opt/flutter/bin/flutter /usr/local/bin/flutter && \
    ln -s /opt/flutter/bin/dart /usr/local/bin/dart && \
    add-apt-repository -y ppa:mozillateam/ppa && \
    echo "Package: *"  > /etc/apt/preferences.d/mozilla-firefox && \
    echo "Pin: release o=LP-PPA-mozillateam" >> /etc/apt/preferences.d/mozilla-firefox && \
    echo "Pin-Priority: 1001" >> /etc/apt/preferences.d/mozilla-firefox && \
    apt-get update && \
    DEBIAN_FRONTEND="noninteractive" apt-get install -y --no-install-recommends firefox && \
    apt-get install -y fonts-noto-core ttf-mscorefonts-installer fonts-roboto fonts-open-sans fonts-font-awesome ttf-ancient-fonts fonts-noto-color-emoji && \
    curl -fsSL https://apt.fury.io/wez/gpg.key | gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg && \
    echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' > /etc/apt/sources.list.d/wezterm.list && \
    chmod 644 /usr/share/keyrings/wezterm-fury.gpg && \
    apt-get update && \
    apt-get install -y wezterm && \
    wget -q https://downloads.vivaldi.com/stable/vivaldi-stable_7.9.3970.45-1_amd64.deb -O /tmp/vivaldi.deb && \
    dpkg -i /tmp/vivaldi.deb || apt-get install -f -y && \
    rm /tmp/vivaldi.deb && \
    wget -q 'https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64' -O /tmp/code.deb && \
    dpkg -i /tmp/code.deb || apt-get install -f -y && \
    rm /tmp/code.deb && \
    rm -rf /var/lib/apt/lists/* && \
    deluser --remove-home ubuntu && \
    locale-gen en_US.UTF-8

COPY --from=builder /tmp/install /
RUN sed -i 's|^Exec=.*|Exec=/usr/bin/pulseaudio|' /etc/xdg/autostart/pulseaudio-xrdp.desktop

ENV LANG=en_US.UTF-8
COPY entrypoint.sh /usr/bin/entrypoint
EXPOSE 3389/tcp
ENTRYPOINT ["/usr/bin/entrypoint"]
