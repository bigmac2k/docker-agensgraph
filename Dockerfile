FROM ubuntu as build

RUN apt-get update && apt-get install -y build-essential libreadline-dev zlib1g-dev flex bison git curl
WORKDIR /build
RUN curl -sSL https://github.com/bitnine-oss/agensgraph/releases/download/v2.1.3/AgensGraph_v2.1.3_linux_CE.tar.gz | tar xz
RUN ./configure
RUN make
RUN make install

# this is copied and adapted from official postgres Dockerfile
FROM ubuntu
COPY --from=build /usr/local/pgsql /usr
RUN set -ex; \
    apt-get update; \
	apt-get install -y --no-install-recommends gnupg dirmngr; \
	rm -rf /var/lib/apt/lists/*
RUN set -eux; \
	groupadd -r postgres --gid=999; \
	useradd -r -g postgres --uid=999 --home-dir=/var/lib/postgresql --shell=/bin/bash postgres; \
	mkdir -p /var/lib/postgresql; \
	chown -R postgres:postgres /var/lib/postgresql
ENV GOSU_VERSION 1.12
RUN set -eux; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates wget; \
	rm -rf /var/lib/apt/lists/*; \
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true
RUN mkdir /docker-entrypoint-initdb.d
RUN set -eux; \
	if [ -f /etc/dpkg/dpkg.cfg.d/docker ]; then \
		grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
		sed -ri '/\/usr\/share\/locale/d' /etc/dpkg/dpkg.cfg.d/docker; \
		! grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
	fi; \
	apt-get update; apt-get install -y --no-install-recommends locales; rm -rf /var/lib/apt/lists/*; \
	localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8
RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libnss-wrapper \
		xz-utils \
	; \
	rm -rf /var/lib/apt/lists/*
RUN set -eux; \
	sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/share/postgresql.conf.sample; \
	grep -F "listen_addresses = '*'" /usr/share/postgresql.conf.sample
RUN mkdir -p /var/run/postgresql && chown -R postgres:postgres /var/run/postgresql && chmod 2777 /var/run/postgresql

ENV PATH $PATH:/usr/lib/postgresql/$PG_MAJOR/bin
ENV PGDATA /var/lib/postgresql/data
RUN mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 777 "$PGDATA"
VOLUME /var/lib/postgresql/data
COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]
STOPSIGNAL SIGINT
EXPOSE 5432
CMD ["postgres"]
