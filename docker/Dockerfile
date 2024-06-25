FROM alpine:3.20.0

LABEL maintainer="Aleksandr Churilov"

RUN apk update && apk add nginx

COPY ./config/nginx.conf /etc/nginx/

COPY ./content/index.html /usr/share/nginx/html/

EXPOSE 80/tcp

CMD ["/usr/sbin/nginx", "-g", "daemon off;"]

