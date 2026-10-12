#!/bin/sh
set -e

cd /var/www/html

php artisan config:cache
php artisan route:cache
php artisan event:cache

# Attende MySQL: al riavvio di Docker "restart: unless-stopped" ignora depends_on e i container partono insieme.
# Reverb non è sulla rete del database e non lo usa.
case "$*" in
    *reverb:start*) ;;
    *)
        tentativi=0
        until php -r 'try { new PDO("mysql:host=".getenv("DB_HOST").";port=".getenv("DB_PORT"), getenv("DB_USERNAME"), getenv("DB_PASSWORD")); } catch (Throwable $e) { exit(1); }'; do
            tentativi=$((tentativi + 1))
            if [ "$tentativi" -ge 60 ]; then
                echo "MySQL non raggiungibile dopo 2 minuti" >&2
                exit 1
            fi
            sleep 2
        done
        ;;
esac

# Solo il container "app" (php-fpm) esegue le migrazioni.
if [ "$1" = "php-fpm" ]; then
    php artisan migrate --force
fi

exec "$@"
