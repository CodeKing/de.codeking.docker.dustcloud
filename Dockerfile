FROM alpine:edge
MAINTAINER CodeKing <frank@codeking.de>

# ADD REPOSITORIES
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

# INSTALL DEPENDENCIES
RUN apk --update upgrade && apk add \
	bash apache2 php7-apache2 curl ca-certificates git php7 tzdata openntpd php7-mysqli mariadb mariadb-client

# COPY PHP BINARY
RUN cp /usr/bin/php7 /usr/bin/php

# SET ENVIRONMENT VARIABLES
ENV MYSQL_HOST="localhost" \
    MYSQL_USER="dustcloud" \
    MYSQL_PASS="dustcloud" \
    MYSQL_BASE="dustcloud" \
    SERVER_IP="10.0.0.10"

# MODIFY APACHE CONFIG
RUN mkdir /run/apache2 \
    && sed -i "s/#LoadModule\ rewrite_module/LoadModule\ rewrite_module/" /etc/apache2/httpd.conf \
    && sed -i "s/#LoadModule\ session_module/LoadModule\ session_module/" /etc/apache2/httpd.conf \
    && sed -i "s/#LoadModule\ session_cookie_module/LoadModule\ session_cookie_module/" /etc/apache2/httpd.conf \
    && sed -i "s/#LoadModule\ session_crypto_module/LoadModule\ session_crypto_module/" /etc/apache2/httpd.conf \
    && sed -i "s/#LoadModule\ deflate_module/LoadModule\ deflate_module/" /etc/apache2/httpd.conf \
    && sed -i "s#^DocumentRoot \".*#DocumentRoot \"/app/public/dustcloud/www\"#g" /etc/apache2/httpd.conf \
    && sed -i "s#/var/www/localhost/htdocs#/app/public/dustcloud/www#" /etc/apache2/httpd.conf \
    && sed -i -e 's/Listen 80/Listen 81/g' /etc/apache2/httpd.conf \
    && printf "\n<Directory \"/app/public\">\n\tAllowOverride All\n</Directory>\n" >> /etc/apache2/httpd.conf

RUN mkdir /app && mkdir /app/public && chown -R apache:apache /app && chmod -R 755 /app && mkdir bootstrap

# MYSQL
RUN chown -R mysql:mysql /var/lib/mysql

# GET DUSTCLOUD
RUN apk add build-base linux-headers subversion python3 python3-dev py-pymysql py-setuptools py-pillow libffi-dev openssl-dev && \
    pip3 install bottle python-miio

WORKDIR /app/public/
RUN svn export https://github.com/dgiese/dustcloud/trunk/dustcloud

# CLEANUP
RUN apk del python3-dev linux-headers build-base libffi-dev subversion py-setuptools
RUN rm -rf /var/cache/apk/*

# INSTALL RUNSCRIPT
ADD run.sh /bootstrap/
RUN chmod +x /bootstrap/run.sh

# PREPARE RUN.SH
RUN apk add --no-cache --virtual .build-deps dos2unix  && \
    dos2unix /bootstrap/run.sh && \
    apk del .build-deps

# EXPOSE PORTS
EXPOSE 80
EXPOSE 81
EXPOSE 1121
EXPOSE 3306
EXPOSE 8053:8053/udp

# LOAD RUNSCRIPT
ENTRYPOINT ["/bootstrap/run.sh"]