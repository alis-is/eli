FROM docker.io/alpine:latest
RUN apk add cmake make perl python3
WORKDIR /root/luabuild/
ENTRYPOINT [ "/root/luabuild/eli", "build.lua" ]
