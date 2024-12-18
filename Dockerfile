FROM alpine:3.21 as artifact-stage

ARG BUILD_DATE
ARG VERSION=LocalBuild
ARG BRANCH=v2-develop
LABEL version=$VERSION
LABEL maintainer="roxedus"

RUN \
  apk add --no-cache \
    curl \
    jq \
    tar && \
  mkdir /build && \
  if [ ${VERSION} == "LocalBuild" ]; then \
    VERSION=$(curl -sX GET https://api.github.com/repos/causefx/Organizr/commits/${BRANCH} \
      | jq -r '.sha'); \
  fi && \
  echo "$VERSION" && \
  curl -o \
    /tmp/organizr.tar.gz -L \
    "https://github.com/causefx/Organizr/archive/${VERSION}.tar.gz" && \
  tar xf /tmp/organizr.tar.gz -C \
    /build --strip-components=1 && \
  mkdir -p /build/data && \
  touch /build/data/.empty && \
  sed -i "s/'branch' => '[^']*',/'branch' =\> '$BRANCH',/" /build/api/config/default.php  && \
  sed -i "s/'commit' => '[^']*',/'commit' =\> '$VERSION',/" /build/api/config/default.php  && \
  echo "$BRANCH" > /build/Docker.txt && \
  echo "$VERSION" > /build/Github.txt

FROM alpine:3.21 as baseimage

ARG BUILD_DATE
ARG VERSION=LocalBuild
LABEL version=$VERSION
LABEL maintainer="roxedus"

ENV S6_REL=3.1.0.1 S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 TZ=Etc/UTC


RUN \
  apk add --no-cache --virtual=build-dependencies \
    tar \
    xz && \
  apk add --no-cache \
    bash \
    ca-certificates \
    coreutils \
    curl \
    libressl3.6-libssl \
    logrotate \
    nano \
    nginx \
    openssl \
    php81 \
    php81-curl \
    php81-fileinfo \
    php81-fpm \
    php81-ftp \
    php81-json \
    php81-ldap \
    php81-mbstring \
    php81-mysqli \
    php81-openssl \
    php81-pdo_sqlite \
    php81-session \
    php81-simplexml \
    php81-sqlite3 \
    php81-tokenizer \
    php81-xml \
    php81-xmlwriter \
    php81-zip \
    php81-zlib \
    shadow \
    tzdata && \
  echo "**** add s6 overlay ****" && \
  curl -o /tmp/s6-overlay-noarch.tar.gz -L \
    "https://github.com/just-containers/s6-overlay/releases/download/v${S6_REL}/s6-overlay-noarch.tar.xz" && \
  tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.gz && \
  curl -o /tmp/s6-overlay-arch.tar.gz -L \
    "https://github.com/just-containers/s6-overlay/releases/download/v${S6_REL}/s6-overlay-$(uname -m).tar.xz" && \
  tar -C / -Jxpf /tmp/s6-overlay-arch.tar.gz && \
  echo "**** create organizr user and make folders ****" && \
  groupmod -g 1000 users && \
  useradd -u 911 -U -d /config -s /bin/false organizr && \
  usermod -G users organizr && \
  echo "**** configure nginx ****" && \
  echo 'fastcgi_param  SCRIPT_FILENAME $document_root$fastcgi_script_name;' >> \
    /etc/nginx/fastcgi_params && \
  rm -f /etc/nginx/conf.d/default.conf && \
  echo "**** fix logrotate ****" && \
  sed -i "s#/var/log/messages {}.*# #g" /etc/logrotate.conf && \
  sed -i 's#/usr/sbin/logrotate /etc/logrotate.conf#/usr/sbin/logrotate /etc/logrotate.conf -s /config/log/logrotate.status#g' /etc/periodic/daily/logrotate && \
  echo "**** enable PHP-FPM ****" && \
  sed -i "s#listen = 127.0.0.1:9000#listen = '/var/run/php81-fpm.sock'#g" /etc/php81/php-fpm.d/www.conf && \
  sed -i "s#;listen.owner = nobody#listen.owner = organizr#g" /etc/php81/php-fpm.d/www.conf && \
  sed -i "s#;listen.group = nobody#listen.group = organizr#g" /etc/php81/php-fpm.d/www.conf && \
  sed -i "s#;listen.mode = nobody#listen.mode = 0660#g" /etc/php81/php-fpm.d/www.conf && \
  echo "**** set our recommended defaults ****" && \
  sed -i "s#pm = dynamic#pm = ondemand#g" /etc/php81/php-fpm.d/www.conf && \
  sed -i "s#pm.max_children = 5#pm.max_children = 4000#g" /etc/php81/php-fpm.d/www.conf && \
  sed -i "s#pm.start_servers = 2#;pm.start_servers = 2#g" /etc/php81/php-fpm.d/www.conf && \
  sed -i "s#;pm.process_idle_timeout = 10s;#pm.process_idle_timeout = 10s;#g" /etc/php81/php-fpm.d/www.conf && \
  sed -i "s#;pm.max_requests = 500#pm.max_requests = 0#g" /etc/php81/php-fpm.d/www.conf && \
  sed -i "s#user = nobody.*#user = organizr#g" /etc/php81/php-fpm.d/www.conf && \
  sed -i "s#group = nobody.*#group = organizr#g" /etc/php81/php-fpm.d/www.conf && \
  sed -i "s#;error_log = log/php81/error.log.*#error_log = /config/log/php/error.log#g" /etc/php81/php-fpm.conf && \
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /var/cache/apk/* \
    /tmp/*

FROM baseimage

COPY --from=artifact-stage /build/ /var/www
RUN  chown -R organizr:organizr /var/www && chmod -R +rw /var/www
COPY root/ /

ENTRYPOINT ["/init"]
