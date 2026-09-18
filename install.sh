#!/bin/sh

TMP_NAME="./$(head -c 24 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)"
PRERELEASE=false
if [ "$1" = "--prerelease" ]; then
    PRERELEASE=true
fi

if command -v curl >/dev/null 2>&1; then
    if curl --help 2>&1 | grep -- "--progress-bar" >/dev/null 2>&1; then
        PROGRESS="--progress-bar"
    fi

    set -- curl -L $PROGRESS -o "$TMP_NAME"
    if [ "$PRERELEASE" = true ]; then
        LATEST=$(curl -sL https://api.github.com/repos/alis-is/eli/releases | grep tag_name | sed 's/  "tag_name": "//g' | sed 's/",//g' | head -n 1 | tr -d '[:space:]')
    else
        LATEST=$(curl -sL https://api.github.com/repos/alis-is/eli/releases/latest | grep tag_name | sed 's/  "tag_name": "//g' | sed 's/",//g' | tr -d '[:space:]')
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget --help 2>&1 | grep -- "--show-progress" >/dev/null 2>&1; then
        PROGRESS="--show-progress"
    fi
    set -- wget -q $PROGRESS -O "$TMP_NAME"
    if [ "$PRERELEASE" = true ]; then
        LATEST=$(wget -qO- https://api.github.com/repos/alis-is/eli/releases | grep tag_name | sed 's/  "tag_name": "//g' | sed 's/",//g' | head -n 1 | tr -d '[:space:]')
    else
        LATEST=$(wget -qO- https://api.github.com/repos/alis-is/eli/releases/latest | grep tag_name | sed 's/  "tag_name": "//g' | sed 's/",//g' | tr -d '[:space:]')
    fi
else
    echo "curl or wget is required to install eli" 1>&2
    exit 1
fi

if [ -z "$LATEST" ]; then
    echo "failed to resolve the latest eli release" 1>&2
    exit 1
fi

if command -v eli >/dev/null 2>&1 && eli -v 2>/dev/null | grep -q "$LATEST"; then
    echo "latest eli already available"
    exit 0
fi

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$OS" in
    linux) ;;
    darwin) OS=macos ;;
    *)
        echo "Unsupported OS: $OS" 1>&2
        exit 1
        ;;
esac
case "$ARCH" in
    x86_64 | amd64) ARCH=x86_64 ;;
    aarch64 | arm64) ARCH=aarch64 ;;
    riscv64) ;;
    *)
        echo "Unsupported architecture: $ARCH" 1>&2
        exit 1
        ;;
esac
if [ "$OS" = "macos" ] && [ "$ARCH" = "riscv64" ]; then
    echo "Unsupported platform: macos-$ARCH" 1>&2
    exit 1
fi

if [ "$OS" = "macos" ]; then
    mkdir -p /usr/local/bin 2>/dev/null || true
fi

BIN="eli"
rm -f "/usr/local/bin/$BIN"
rm -f "/usr/bin/$BIN"
rm -f "/bin/$BIN"
rm -f "/usr/local/sbin/$BIN"
rm -f "/usr/sbin/$BIN"
rm -f "/sbin/$BIN"
# check destination folder
if [ -w "/usr/local/bin" ]; then
    DESTINATION="/usr/local/bin/$BIN"
elif [ -w "/usr/local/sbin" ]; then
    DESTINATION="/usr/local/sbin/$BIN"
elif [ -w "/usr/bin" ]; then
    DESTINATION="/usr/bin/$BIN"
elif [ -w "/usr/sbin" ]; then
    DESTINATION="/usr/sbin/$BIN"
elif [ -w "/bin" ]; then
    DESTINATION="/bin/$BIN"
elif [ -w "/sbin" ]; then
    DESTINATION="/sbin/$BIN"
else
    echo "No writable system binary directory found, installing locally."
    DESTINATION="./$BIN"
fi

if [ "$PRERELEASE" = true ]; then
    echo "downloading latest eli prerelease for $OS-$ARCH..."
else
    echo "downloading eli-$OS-$ARCH $LATEST..."
fi

if "$@" "https://github.com/alis-is/eli/releases/download/$LATEST/eli-$OS-$ARCH" &&
    cp "$TMP_NAME" "$DESTINATION" && rm "$TMP_NAME" && chmod +x "$DESTINATION"; then
    if [ "$PRERELEASE" = true ]; then
        echo "latest eli prerelease for $OS-$ARCH successfully installed"
    else
        echo "eli $LATEST for $OS-$ARCH successfully installed"
    fi
else
    echo "eli installation failed!" 1>&2
    exit 1
fi
