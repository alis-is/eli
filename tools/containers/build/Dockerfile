FROM docker.io/alpine:latest
RUN apk add cmake make perl python3 openssl
ENTRYPOINT [ "./eli", "tools/build.lua" ]