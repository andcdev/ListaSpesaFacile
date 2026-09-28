#!/bin/sh
set -e

cd /var/www/html

php artisan config:cache
php artisan route:cache
php artisan event:cache

# Solo il container "app" (php-fpm) esegue le migrazioni.
if [ "$1" = "php-fpm" ]; then
    php artisan migrate --force
fi

exec "$@"
