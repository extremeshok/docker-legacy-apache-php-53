FROM ubuntu:precise
MAINTAINER Adrian Kriel <admin@extremeshok.com>

# apache with mod php 5.3 with geoip, memcached, mysql, sqlite, imagick, gnutls

ENV DEBIAN_FRONTEND=noninteractive

ENV PHP_VERSION=5.3 \
	OS_LOCALE="en_US.UTF-8"
RUN locale-gen ${OS_LOCALE}
ENV LANG=${OS_LOCALE} \
    LANGUAGE=${OS_LOCALE} \
    LC_ALL=${OS_LOCALE}

WORKDIR /tmp/provisioning/

RUN apt-get update \
	&& SOFTWARE_BUILD_DEPS=" \
	apt-transport-https \
	build-essential \
	lsb-release \
	make \
	python-software-properties \
	software-properties-common \
	unzip \
	" \
# Install
	&& apt-get install --no-install-recommends -y $SOFTWARE_BUILD_DEPS sudo curl iputils-ping \
	&& add-apt-repository -y ppa:rip84/php5 \
	&& rm -rf /var/lib/apt/lists/*

# install APACHE and Modules
RUN apt-get update \
	&& APACHE_BUILD_DEPS=" \
		$APACHE_EXTRA_BUILD_DEPS \
		apache2 \
		apache2-threaded-dev \
		libapache2-mod-geoip \
		libapache2-mod-gnutls \
		libapache2-mod-php5 \
		" \
	&& set -x \
	&& apt-get install --no-install-recommends -y $APACHE_BUILD_DEPS \
# disable default configs
  && rm -f /etc/apache2/sites-enabled/000-default \
  && rm -f /etc/apache2/sites-available/default \
	&& rm -rf /var/lib/apt/lists/*

	# install APACHE and Modules
	RUN apt-get update \
		&& set -x \
		&& curl https://raw.githubusercontent.com/joeyhub/mod_remoteip-httpd22/master/mod_remoteip.c -o /tmp/mod_remoteip.c \
		&& apxs2 -i -c -n mod_remoteip.so /tmp/mod_remoteip.c \
		&& chmod 644 /usr/lib/apache2/modules/mod_remoteip.so \
		&& rm -f /tmp/mod_remoteip.* \
	# disable default configs
		&& rm -rf /var/lib/apt/lists/*

# install PHP and extensions
RUN apt-get update \
	&& PHP_BUILD_DEPS=" \
		$PHP_EXTRA_BUILD_DEPS \
		php-apc \
		php-pear \
		php5-cli \
		php5-curl \
		php5-dev \
		php5-intl \
		php5-fpm \
		php5-gd \
		php5-geoip \
		php5-imagick \
		php5-imap \
		php5-json \
		php5-mcrypt \
		php5-memcached \
		php5-mysql \
		php5-ps \
		php5-pspell \
		php5-recode \
		php5-sqlite \
		php5-tidy \
		" \
	&& set -x \
	&& apt-get install --no-install-recommends -y $PHP_BUILD_DEPS \
  && rm -rf /var/lib/apt/lists/*


# php-redis
RUN curl -Ss https://codeload.github.com/phpredis/phpredis/zip/master -o /tmp/provisioning/phpredis.zip \
	&& unzip -o /tmp/provisioning/phpredis.zip -d /tmp/provisioning/ \
	&& cd /tmp/provisioning/phpredis-master \
	&& phpize \
	&& ./configure \
	&& make \
	&& make install \
	&& echo extension=redis.so > /etc/php5/conf.d/redis.ini \
	&& rm -rf /tmp/provisioning/phpredis-master \
	&& rm -f /tmp/provisioning/phpredis.zip \
	&& rm -rf /var/lib/apt/lists/*

# Enable APACHE Modules
RUN APACHE_ENABLE_MODULES=" \
		$APACHE_EXTRA_ENABLE_MODULES \
		actions \
		alias \
		auth_basic \
		authn_file \
		authz_default \
		authz_groupfile \
		authz_host \
		authz_user \
		autoindex \
		deflate \
		dir \
		env \
		expires \
		geoip \
		headers \
		mime \
		negotiation \
		php5 \
		reqtimeout \
		rewrite \
		setenvif \
		ssl \
		status \
		" \
	&& set -x \
	&& a2enmod $APACHE_ENABLE_MODULES \
# fix permissions
#	&& chown -R www-data:www-data /var/lib/php5 \
	&& mkdir -p /var/www \
	&& chown -R www-data:www-data /var/www \
# CLEANUP
	&& rm -rf /var/lib/apt/lists/*

# Forward request and error logs to docker log collector
RUN	 mkdir -p /var/log/php \
	&& mkdir -p /var/log/apache2 \
	&& ln -sf /dev/stdout /var/log/apache2/access.log \
	&& ln -sf /dev/stderr /var/log/apache2/error.log \
	&& ln -sf /dev/stderr /var/log/php/error.log

RUN	curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# GEOIP databases
RUN mkdir -p /usr/share/GeoIP && cd /usr/share/GeoIP \
	&& curl -sS http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz -o GeoIP.dat.gz \
	&& gunzip GeoIP.dat.gz \
	&& curl -sS http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz -o GeoLiteCity.dat.gz \
	&& gunzip GeoLiteCity.dat.gz \
	&& curl -sS http://download.maxmind.com/download/geoip/database/asnum/GeoIPASNum.dat.gz -o GeoIPASNum.dat.gz \
	&& gunzip GeoIPASNum.dat.gz \
	&& rm -f /usr/share/GeoIP/*.dat.gz

# Supervisor Demon manager and cron
RUN apt-get update \
	&& apt-get install -y --no-install-recommends cron supervisor

RUN apt-get update \
	&& apt-get purge -y --auto-remove $SOFTWARE_BUILD_DEPS \
	&& rm -rf /tmp/provisioning \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/

EXPOSE 80 443

COPY ./rootfs/etc/apache2/conf.d/other-vhosts-access-log /etc/apache2/conf.d/other-vhosts-access-log
COPY ./rootfs/etc/apache2/mods-enabled/geoip.conf /etc/apache2/mods-enabled/geoip.conf
COPY ./rootfs/etc/apache2/mods-enabled/negotiation.conf /etc/apache2/mods-enabled/negotiation.conf
COPY ./rootfs/etc/apache2/sites-enabled/default.conf /etc/apache2/sites-enabled/default.conf
COPY ./rootfs/etc/apache2/apache2.conf /etc/apache2/apache2.conf
COPY ./rootfs/etc/php5/apache2/conf.d/apc.ini /etc/php5/apache2/conf.d/apc.ini
COPY ./rootfs/etc/php5/apache2/conf.d/custom.ini /etc/php5/apache2/conf.d/custom.ini

COPY ./rootfs/etc/supervisord/ /etc/supervisor/
COPY ./rootfs/usr/local/bin/supervisor-watcher /usr/local/bin/supervisor-watcher
COPY ./rootfs/usr/local/bin/sigproxy /usr/local/bin/sigproxy

RUN chmod 777 /usr/local/bin/supervisor-watcher
RUN chmod 777 /usr/local/bin/sigproxy

CMD ["/usr/bin/supervisord"]