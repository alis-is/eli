#!/bin/sh

TMP_NAME="/tmp/$(head -n 1 -c 32 /dev/urandom | tr -dc 'a-zA-Z0-9'| fold -w 32)"

if which curl > /dev/null; then
    if curl --help | grep "--progress-bar"; then
        PROGRESS="--progress-bar"
    fi

    set -- curl -L $PROGRESS -o "$TMP_NAME"
    LATEST=$(curl -sL https://api.github.com/repos/alis-is/eli/releases/latest | grep tag_name | sed 's/  "tag_name": "//g' | sed 's/",//g')
else
    if wget --help | grep "--show-progress"; then
        PROGRESS="--show-progress"
    fi
    set -- wget -q $PROGRESS -O "$TMP_NAME"
    LATEST=$(wget -qO- https://api.github.com/repos/alis-is/eli/releases/latest | grep tag_name | sed 's/  "tag_name": "//g' | sed 's/",//g')
fi

if eli -v | grep "$LATEST"; then
    echo "Latest eli already available."
    exit 0
fi

PLATFORM=$(uname -m)
echo "Downloading eli-unix-$PLATFORM $LATEST..."

if "$@" "https://github.com/alis-is/eli/releases/download/$LATEST/eli-unix-$PLATFORM" &&
    mv "$TMP_NAME" /usr/sbin/eli &&
    chmod +x /usr/sbin/eli; then
    echo "eli $LATEST for $PLATFORM successfuly installed."
else 
    echo "eli installation failed!" 1>&2
    exit 1
fi