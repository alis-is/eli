## Building eli-build for github packages

1. `docker login ghcr.io --username <username>`
2. `docker build -t eli-build ./containers/build/github`
3. `docker tag localhost/eli-build:latest ghcr.io/<owner>/eli-build:<version>`
4. `docker push ghcr.io/alis-is/eli-build:<version>`