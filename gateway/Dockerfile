FROM nginx:alpine

RUN apk add --no-cache gettext

COPY nginx.conf.template /etc/nginx/nginx.conf.template

EXPOSE 8080

CMD ["/bin/sh", "-c", "envsubst '\\$IAM_SERVICE_HOST \\$HARDWARE_SERVICE_HOST \\$ANALYTICS_SERVICE_HOST \\$WEATHER_SERVICE_HOST \\$NOTIFICATION_SERVICE_HOST' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf && exec nginx -g 'daemon off;'"]