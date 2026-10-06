FROM nginx:1.27-bookworm

USER root

RUN apt-get update && \
    apt-get install -y \
        iperf3 \
        iproute2 \
        openssl \
        procps \
        curl \
        ca-certificates \
        tcpdump && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/certs \
    /usr/share/nginx/html \
    /results

EXPOSE 443/tcp
EXPOSE 443/udp
EXPOSE 5201/tcp
EXPOSE 5201/udp