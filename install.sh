#!/bin/sh

TMP_NAME="./$(head -n 1 -c 32 /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32)"
PRERELEASE=false
if [ "$1" = "--prerelease" ]; then
    PRERELEASE=true
fi

if which curl >/dev/null; then
    if curl --help 2>&1 | grep "--progress-bar" >/dev/null 2>&1; then
        PROGRESS="--progress-bar"
    fi

    set -- curl -L $PROGRESS -o "$TMP_NAME"
    if [ "$PRERELEASE" = true ]; then
        LATEST=$(curl -sL https://api.github.com/repos/alis-is/eli/releases | grep tag_name | sed 's/  "tag_name": "//g' | sed 's/",//g' | head -n 1 | tr -d '[:space:]')
    else
        LATEST=$(curl -sL https://api.github.com/repos/alis-is/eli/releases/latest | grep tag_name | sed 's/  "tag_name": "//g' | sed 's/",//g' | tr -d '[:space:]')
    fi
else
    if wget --help 2>&1 | grep "--show-progress" >/dev/null 2>&1; then
        PROGRESS="--show-progress"
    fi
    set -- wget -q $PROGRESS -O "$TMP_NAME"
    if [ "$PRERELEASE" = true ]; then
        LATEST=$(wget -qO- https://api.github.com/repos/alis-is/eli/releases | grep tag_name | sed 's/  "tag_name": "//g' | sed 's/",//g' | head -n 1 | tr -d '[:space:]')
    else
        LATEST=$(wget -qO- https://api.github.com/repos/alis-is/eli/releases/latest | grep tag_name | sed 's/  "tag_name": "//g' | sed 's/",//g' | tr -d '[:space:]')
    fi
fi

if eli -v | grep "$LATEST"; then
    echo "latest eli already available"
    exit 0
fi

BIN="eli"
rm -f "/usr/local/bin/$BIN"
rm -f "/usr/bin/$BIN"
rm -f "/bin/$BIN"
rm -f "/usr/local/sbin/$BIN"
rm -f "/usr/sbin/$BIN"
rm -f "/sbin/$BIN"
# check destination folder
if [ -d "/usr/bin" ]; then
    DESTINATION="/usr/bin/$BIN"
elif [ -d "/bin" ]; then
    DESTINATION="/bin/$BIN"
elif [ -d "/usr/sbin" ]; then
    DESTINATION="/usr/sbin/$BIN"
elif [ -d "/sbin" ]; then
    DESTINATION="/sbin/$BIN"
else
    echo "no suitable destination folder found" 1>&2
    exit 1
fi

PLATFORM=$(uname -m)
if [ "$1" = "--prerelease" ]; then
    echo "downloading latest eli prerelease for $PLATFORM..."
else
    echo "downloading eli-linux-$PLATFORM $LATEST..."
fi

if "$@" "https://github.com/alis-is/eli/releases/download/$LATEST/eli-linux-$PLATFORM" &&
    cp "$TMP_NAME" "$DESTINATION" && rm "$TMP_NAME" && chmod +x "$DESTINATION"; then
    if [ "$1" = "--prerelease" ]; then
        echo "latest eli prerelease for $PLATFORM successfully installed"
    else
        echo "eli $LATEST for $PLATFORM successfully installed"
    fi
else
    echo "eli installation failed!" 1>&2
    exit 1
fi
