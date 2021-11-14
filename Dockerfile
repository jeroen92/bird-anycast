FROM alpine:3.12 as build

ARG BIRD_VERSION=2.0.7

WORKDIR /tmp/build

RUN apk add --no-cache build-base curl flex bison linux-headers ncurses-dev readline-dev \
	&& curl -o bird.tar.gz "https://bird.network.cz/download/bird-${BIRD_VERSION}.tar.gz" \
	&& tar xf bird.tar.gz --strip 1 \
	&& ./configure --host=aarch64-unknown-linux-musl --build=aarch64-unknown-linux-musl \
	&& make -j 2 \
	&& make install

FROM alpine:3.12

RUN apk add ncurses-dev readline-dev py3-psutil=5.7.0-r0 py3-click=7.1.2-r0 docker-py=4.2.0-r0 supervisor=4.2.0-r0 \
	&& adduser -s /sbin/nologin -h /dev/null -D -u 1000 bird

COPY --from=build /usr/local/sbin/ /usr/local/sbin/
COPY --from=build --chown=1000:1000 /usr/local/etc/bird.conf /usr/local/etc/bird.conf
COPY --from=build --chown=1000:1000 /usr/local/var/run/ /usr/local/var/run/
COPY files/supervisord.conf /etc/supervisord.conf
COPY files/anycast-bird /usr/local/bin/anycast-bird

HEALTHCHECK --interval=5s --timeout=3s --start-period=10s --retries=3 \
	CMD ["/usr/local/sbin/birdc", "show", "status"]

ENTRYPOINT [ "/usr/bin/supervisord", "-c", "/etc/supervisord.conf", "-n" ]
