FROM docker.io/alpine:latest
RUN apk add cmake make perl python3 openssl
RUN mkdir /opt/cross
RUN wget https://more.musl.cc/11/x86_64-linux-musl/x86_64-linux-musl-cross.tgz && tar -xzvf x86_64-linux-musl-cross.tgz && mv x86_64-linux-musl-cross /opt/cross/
RUN wget https://more.musl.cc/11/x86_64-linux-musl/i686-linux-musl-cross.tgz && tar -xzvf i686-linux-musl-cross.tgz && mv i686-linux-musl-cross /opt/cross/
RUN wget https://more.musl.cc/11/x86_64-linux-musl/aarch64-linux-musl-cross.tgz && tar -xzvf aarch64-linux-musl-cross.tgz && mv aarch64-linux-musl-cross /opt/cross/
RUN wget https://more.musl.cc/11/x86_64-linux-musl/x86_64-w64-mingw32-cross.tgz && tar -xzvf x86_64-w64-mingw32-cross.tgz && mv x86_64-w64-mingw32-cross /opt/cross/
RUN wget https://more.musl.cc/11/x86_64-linux-musl/i686-w64-mingw32-cross.tgz && tar -xzvf i686-w64-mingw32-cross.tgz && mv i686-w64-mingw32-cross /opt/cross/
RUN rm -f *.tgz
ENTRYPOINT [ "./eli", "tools/build.lua" ]