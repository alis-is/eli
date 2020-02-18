#!/bin/sh

LATEST=$(curl -sL https://api.github.com/repos/cryon-io/eli/releases/latest | grep tag_name | sed 's/  "tag_name": "//g' | sed 's/",//g')

wget "https://github.com/cryon-io/eli/releases/download/$LATEST/eli-unix-$(uname -p)" -O eli &&
    mv eli /usr/sbin/eli &&
    chmod +x /usr/sbin/eli &&
    echo "eli $LATEST for $(uname -p) successfuly installed."
