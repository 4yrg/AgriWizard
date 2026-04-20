FROM kong:3.4

USER root

COPY infrastructure/kong/kong.yml /etc/kong/kong.template.yml
COPY infrastructure/kong/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENV KONG_DATABASE=off \
    KONG_LOG_LEVEL=info \
    KONG_PROXY_LISTEN=0.0.0.0:8000 \
    KONG_ADMIN_LISTEN=0.0.0.0:8001 \
    KONG_PROXY_ACCESS_LOG=/dev/stdout \
    KONG_ADMIN_ACCESS_LOG=/dev/stderr \
    KONG_PROXY_ERROR_LOG=/dev/stderr \
    KONG_ADMIN_ERROR_LOG=/dev/stderr

ENTRYPOINT ["/entrypoint.sh"]
