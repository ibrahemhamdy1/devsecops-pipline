# ============================================================
# Multi-stage Dockerfile — Laravel 11 / PHP 8.3
# Stages: deps-composer → deps-node → build → production
# ============================================================

ARG PHP_VERSION=8.3

# ── Stage 1: Composer dependencies ──────────────────────────
FROM composer:2.7 AS deps-composer

WORKDIR /app
COPY composer.json composer.lock* ./

RUN composer install \
      --no-dev \
      --no-interaction \
      --no-progress \
      --prefer-dist \
      --optimize-autoloader \
      --no-scripts

COPY . .

RUN composer run-script post-autoload-dump || true

# ── Stage 2: Production image ────────────────────────────────
FROM php:${PHP_VERSION}-fpm-alpine AS production

ARG BUILD_DATE
ARG VCS_REF
ARG VERSION=1.0.0

LABEL org.opencontainers.image.title="laravel-devsecops" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}"

# Security: non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Install system packages + PHP extensions
RUN apk add --no-cache \
      nginx \
      supervisor \
      curl \
      tzdata \
      libpng-dev \
      libzip-dev \
      icu-dev \
    && docker-php-ext-install \
      pdo_mysql \
      pdo_sqlite \
      zip \
      intl \
      opcache \
    && docker-php-ext-enable opcache \
    && rm -rf /tmp/*

# OPcache tuning for production
RUN { \
    echo 'opcache.enable=1'; \
    echo 'opcache.memory_consumption=256'; \
    echo 'opcache.interned_strings_buffer=16'; \
    echo 'opcache.max_accelerated_files=20000'; \
    echo 'opcache.revalidate_freq=0'; \
    echo 'opcache.validate_timestamps=0'; \
    echo 'opcache.jit=tracing'; \
    echo 'opcache.jit_buffer_size=100M'; \
} > /usr/local/etc/php/conf.d/opcache.ini

WORKDIR /var/www/html

# Copy app from composer stage
COPY --from=deps-composer --chown=appuser:appgroup /app/vendor ./vendor
COPY --chown=appuser:appgroup . .

# Nginx config
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/supervisord.conf /etc/supervisord.conf

# Laravel bootstrap
RUN php artisan config:cache \
    && php artisan route:cache \
    && php artisan view:cache \
    && chown -R appuser:appgroup storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/api/health || exit 1

USER appuser

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
