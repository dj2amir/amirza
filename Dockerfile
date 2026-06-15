FROM php:8.2-apache

RUN apt-get update && apt-get install -y --no-install-recommends \
    cron \
    supervisor \
    unzip \
    git \
    wget \
    jq \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libicu-dev \
    libxml2-dev \
    libbcmath-dev \
    libsoap-dev \
    libssh2-1-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    mysqli \
    mbstring \
    zip \
    gd \
    curl \
    intl \
    xml \
    bcmath \
    soap \
    ssh2 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN a2enmod rewrite

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

COPY apache-config/000-default.conf /etc/apache2/sites-available/000-default.conf

COPY --chown=www-data:www-data . /var/www/html/

RUN mkdir -p /var/www/html/storage/cache \
    && chown -R www-data:www-data /var/www/html/storage

WORKDIR /var/www/html

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
