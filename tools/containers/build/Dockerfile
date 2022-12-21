FROM docker.io/alpine:latest
RUN apk add cmake make perl python3 py3-pip openssl
RUN pip install jsonschema jinja2
ENTRYPOINT [ "./eli", "tools/build.lua" ]