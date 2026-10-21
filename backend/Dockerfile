# Immagine unica usata sia da PHP-FPM (API) sia dal server WebSocket Reverb.
# Versione esatta di PHP: una patch di sicurezza e' un commit che cambia il
# numero, e la build scarica il tag nuovo anche senza --pull. 8.5.12: PHP2Shell.
FROM php:8.5.12-fpm-alpine

ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/
RUN install-php-extensions pdo_mysql pcntl opcache intl zip bcmath

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction

COPY . .
RUN composer dump-autoload --optimize --no-dev \
    && chown -R www-data:www-data storage bootstrap/cache

COPY docker/php.ini $PHP_INI_DIR/conf.d/zz-app.ini

ENTRYPOINT ["/var/www/html/docker/entrypoint.sh"]
CMD ["php-fpm"]
