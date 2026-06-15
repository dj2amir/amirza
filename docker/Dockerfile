FROM php:8.2-apache

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and cron
RUN apt-get update && apt-get install -y --no-install-recommends \
    cron \
    libzip-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libicu-dev \
    libxml2-dev \
    libonig-dev \
    libcurl4-openssl-dev \
    libssh2-1-dev \
    unzip \
    curl \
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
        opcache \
    && pecl install ssh2 \
    && docker-php-ext-enable ssh2 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Enable Apache modules
RUN a2enmod rewrite ssl headers

# Set recommended PHP settings
RUN { \
    echo 'memory_limit = -1'; \
    echo 'max_execution_time = 300'; \
    echo 'upload_max_filesize = 64M'; \
    echo 'post_max_size = 64M'; \
    echo 'max_input_time = 300'; \
    echo 'default_charset = UTF-8'; \
    echo 'error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT'; \
    echo 'log_errors = On'; \
    echo 'error_log = /var/log/php_errors.log'; \
    } > /usr/local/etc/php/conf.d/mirzabot.ini

# Create app directory structure
RUN mkdir -p /var/www/html/mirzabotconfig \
    && mkdir -p /var/www/html/mirzabotconfig/storage/cache \
    && mkdir -p /var/www/html/mirzabotconfig/data \
    && mkdir -p /var/log/apache2 \
    && mkdir -p /var/run/cron

# Copy application files
COPY --chown=www-data:www-data . /var/www/html/mirzabotconfig/

# Ensure proper permissions for www-data
RUN chown -R www-data:www-data /var/www/html/mirzabotconfig \
    && chmod -R 755 /var/www/html/mirzabotconfig \
    && chmod -R 775 /var/www/html/mirzabotconfig/storage \
    && chmod -R 775 /var/www/html/mirzabotconfig/data

# Set up cron for www-data user
RUN touch /var/log/cron.log \
    && chmod 0644 /var/log/cron.log

# Copy entrypoint script
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Copy Apache vhost config
COPY docker/apache-vhost.conf /etc/apache2/sites-available/000-default.conf

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

WORKDIR /var/www/html/mirzabotconfig

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]
