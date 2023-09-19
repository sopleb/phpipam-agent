FROM php:5.6-zts-stretch
MAINTAINER Pierre Cheynier <pierre.cheynier@gmail.com>

ENV PHPIPAM_AGENT_SOURCE https://github.com/phpipam/phpipam-agent

# Replace sources with archive
RUN echo 'deb http://archive.debian.org/debian/ stretch main contrib non-free\n\
deb http://archive.debian.org/debian/ stretch-proposed-updates main contrib non-free\n\
deb http://archive.debian.org/debian-security stretch/updates main contrib non-free\n'\
> /etc/apt/sources.list

# Install required deb packages
RUN apt-get update && apt-get -y upgrade && \
    rm /etc/apt/preferences.d/no-debian-php && \
    apt-get install -y git cron libgmp-dev iputils-ping fping && \
    rm -rf /var/lib/apt/lists/*

# Configure apache and required PHP modules
RUN docker-php-ext-configure mysqli --with-mysqli=mysqlnd && \
    docker-php-ext-install mysqli && \
    docker-php-ext-install json && \
    docker-php-ext-install pdo_mysql && \
    ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h && \
    docker-php-ext-configure gmp --with-gmp=/usr/include/x86_64-linux-gnu && \
    docker-php-ext-install gmp && \
    docker-php-ext-install pcntl

COPY php.ini /usr/local/etc/php/

# Clone phpipam-agent sources
WORKDIR /opt/
RUN git clone ${PHPIPAM_AGENT_SOURCE}.git

WORKDIR /opt/phpipam-agent
# Use system environment variables into config.php
RUN cp config.dist.php config.php && \
    sed -i -e "s/\['key'\] = .*;/\['key'\] = getenv(\"PHPIPAM_AGENT_KEY\");/" \
    -e "s/\['pingpath'\] = .*;/\['pingpath'\] = \"\/usr\/bin\/fping\";/" \
    -e "s/\['db'\]\['host'\] = \"localhost\"/\['db'\]\['host'\] = getenv(\"MYSQL_ENV_MYSQL_HOST\") ?: \"mysql\"/" \
    -e "s/\['db'\]\['user'\] = \"phpipam\"/\['db'\]\['user'\] = getenv(\"MYSQL_ENV_MYSQL_USER\") ?: \"root\"/" \
    -e "s/\['db'\]\['pass'\] = \"phpipamadmin\"/\['db'\]\['pass'\] = getenv(\"MYSQL_ENV_MYSQL_PASSWORD\")/" \
    -e "s/\['db'\]\['name'\] = \"phpipam\"/\['db'\]\['name'\] = getenv(\"MYSQL_ENV_MYSQL_NAME\") ?: \"phpipam\"/" \
    -e "s/\['db'\]\['port'\] = 3306;/\['db'\]\['port'\] = 3306;\n\n\$password_file = getenv(\"MYSQL_ENV_MYSQL_PASSWORD_FILE\");\nif(file_exists(\$password_file))\n\$db\['db'\]\['pass'\] = preg_replace(\"\/\\\\s+\/\", \"\", file_get_contents(\$password_file));/" \
    config.php

# Setup crontab
ENV CRONTAB_FILE=/etc/cron.d/phpipam
RUN echo "* * * * * /usr/local/bin/php /opt/phpipam-agent/index.php update > /proc/1/fd/1 2>/proc/1/fd/2" > ${CRONTAB_FILE} && \
    chmod 0644 ${CRONTAB_FILE} && \
    crontab ${CRONTAB_FILE}

CMD [ "sh", "-c", "printenv > /etc/environment && cron -f" ]

