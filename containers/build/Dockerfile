FROM docker.io/alpine:latest
RUN apk add cmake make perl python3 py3-pip openssl git
RUN pip install jsonschema jinja2
RUN mkdir /usr/local/zig
# setup eli
RUN wget -q https://raw.githubusercontent.com/alis-is/eli/main/install.sh -O /tmp/install.sh && \
	sh /tmp/install.sh
# setup zig
RUN export ZIG_VERSION=3258+7621e5693 && \
	wget https://ziglang.org/builds/zig-linux-x86_64-0.11.0-dev.$ZIG_VERSION.tar.xz && \
	mkdir zig && tar --xz -xf zig-linux-x86_64-0.11.0-dev.$ZIG_VERSION.tar.xz --directory zig && \
	cp -rf zig/zig*/* --target-directory=/usr/local/zig
RUN ln -s /usr/local/zig/zig /bin/zig
RUN rm -f *.tgz
ENTRYPOINT [ "eli", "tools/build.lua" ]