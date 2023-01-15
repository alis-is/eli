FROM docker.io/alpine:latest
RUN apk add qemu-i386 qemu-aarch64 qemu-x86_64
ENTRYPOINT [ "./tools/test.sh" ]