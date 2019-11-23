FROM docker.io/alpine:latest
RUN apk add cmake make perl
WORKDIR /root/luabuild/
ENTRYPOINT [ "/root/luabuild/eli", "build.lua" ]
