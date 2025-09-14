FROM php:8.4-fpm-alpine

# Устанавливаем нужные пакеты
RUN apk add --no-cache \
    curl \
    $PHPIZE_DEPS \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libxml2-dev \
    zip \
    unzip \
    git \
    oniguruma-dev \
    libzip-dev \
    linux-headers \
    fcgi \
    && pecl channel-update pecl.php.net \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && docker-php-ext-install \
    pdo \
    pdo_mysql \
    mysqli \
    mbstring \
    xml \
    gd \
    bcmath \
    zip \
    && apk del $PHPIZE_DEPS

# Удаляем стандартные примеры конфигураций, чтобы не мешали кастомным
RUN rm -f /usr/local/etc/php-fpm.d/zz-docker.conf

# Устанавливаем Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Устанавливаем рабочую директорию
WORKDIR /var/www/html

# Запускаем PHP-FPM в foreground режиме
CMD ["php-fpm", "-F"]
