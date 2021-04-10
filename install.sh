#!/bin/sh

LATEST=$(curl -sL https://api.github.com/repos/cryon-io/eli/releases/latest | grep tag_name | sed 's/  "tag_name": "//g' | sed 's/",//g')

TMP_NAME="/tmp/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)"

wget "https://github.com/cryon-io/eli/releases/download/$LATEST/eli-unix-$(uname -m)" -O "$TMP_NAME" &&
    mv "$TMP_NAME" /usr/sbin/eli &&
    chmod +x /usr/sbin/eli &&
    echo "eli $LATEST for $(uname -m) successfuly installed."
