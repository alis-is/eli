FROM docker.io/alpine:latest
RUN apk add cmake make perl python3 py3-pip py3-jinja2 py3-jsonschema openssl git 
RUN mkdir /usr/local/zig
# setup eli
RUN wget -q https://raw.githubusercontent.com/alis-is/eli/main/install.sh -O /tmp/install.sh && \
	sh /tmp/install.sh
# setup zig
RUN export ZIG_VERSION=0.14.1 && \
	wget https://ziglang.org/download/$ZIG_VERSION/zig-x86_64-linux-$ZIG_VERSION.tar.xz && \
	mkdir zig && tar --xz -xf zig-x86_64-linux-$ZIG_VERSION.tar.xz --directory zig && \
	cp -rf zig/zig*/* --target-directory=/usr/local/zig
RUN ln -s /usr/local/zig/zig /bin/zig
RUN rm -f *.tgz
ENTRYPOINT [ "eli", "tools/build.lua" ]