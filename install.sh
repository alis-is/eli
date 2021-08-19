#!/bin/sh

TMP_NAME="/tmp/$(head -n 1 -c 32 /dev/urandom | tr -dc 'a-zA-Z0-9'| fold -w 32)"

if which curl > /dev/null; then
    set -- curl -L --progress-bar -o "$TMP_NAME"
    LATEST=$(curl -sL https://api.github.com/repos/cryon-io/eli/releases/latest | grep tag_name | sed 's/  "tag_name": "//g' | sed 's/",//g')
else 
    set -- wget -q --show-progress -O "$TMP_NAME"
    LATEST=$(wget -qO- https://api.github.com/repos/cryon-io/eli/releases/latest | grep tag_name | sed 's/  "tag_name": "//g' | sed 's/",//g')
fi

PLATFORM=$(uname -m)
echo "Downloading eli-unix-$PLATFORM $LATEST..."

if "$@" "https://github.com/cryon-io/eli/releases/download/$LATEST/eli-unix-$PLATFORM" &&
    mv "$TMP_NAME" /usr/sbin/eli &&
    chmod +x /usr/sbin/eli; then
    echo "eli $LATEST for $PLATFORM successfuly installed."
else 
    echo "eli installation failed!" 1>&2
    exit 1
fi
