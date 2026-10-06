FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV OPENSSL_VERSION=3.5.4
ENV PATH="/opt/curl/bin:/opt/openssl/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/openssl/lib:/opt/nghttp3/lib:/opt/ngtcp2/lib"


RUN apt-get update && apt-get install -y \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    git \
    ca-certificates \
    perl \
    cmake \
    ninja-build \
    libnghttp2-dev \
    libev-dev \
    libc-ares-dev \
    zlib1g-dev \
    libbrotli-dev \
    libzstd-dev \
    libpsl-dev \
    iperf3 \
    tshark \
    tcpdump \
    iproute2 \
    iputils-ping \
    procps \
    jq \
    python3 \
    python3-pip \
    python3-pandas \
    python3-matplotlib \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp


RUN git clone --depth 1 \
    --branch openssl-${OPENSSL_VERSION} \
    https://github.com/openssl/openssl.git && \
    cd openssl && \
    ./config \
        --prefix=/opt/openssl \
        --libdir=lib && \
    make -j$(nproc) && \
    make install_sw


WORKDIR /tmp

RUN git clone --depth 1 --recurse-submodules \
    https://github.com/ngtcp2/nghttp3.git && \
    cd nghttp3 && \
    git submodule update --init --recursive && \
    autoreconf -fi && \
    ./configure \
        --prefix=/opt/nghttp3 \
        --enable-lib-only && \
    make -j$(nproc) && \
    make install


WORKDIR /tmp

RUN git clone --depth 1 --recurse-submodules \
    https://github.com/ngtcp2/ngtcp2.git && \
    cd ngtcp2 && \
    git submodule update --init --recursive && \
    autoreconf -fi && \
    PKG_CONFIG_PATH=/opt/openssl/lib/pkgconfig:/opt/nghttp3/lib/pkgconfig \
    LDFLAGS="-Wl,-rpath,/opt/openssl/lib" \
    ./configure \
        --prefix=/opt/ngtcp2 \
        --enable-lib-only \
        --with-openssl && \
    make -j$(nproc) && \
    make install


RUN echo "/opt/openssl/lib" > /etc/ld.so.conf.d/openssl.conf && \
    echo "/opt/nghttp3/lib" > /etc/ld.so.conf.d/nghttp3.conf && \
    echo "/opt/ngtcp2/lib" > /etc/ld.so.conf.d/ngtcp2.conf && \
    ldconfig


WORKDIR /tmp

RUN git clone --depth 1 \
    https://github.com/curl/curl.git && \
    cd curl && \
    autoreconf -fi && \
    PKG_CONFIG_PATH=/opt/openssl/lib/pkgconfig:/opt/ngtcp2/lib/pkgconfig:/opt/nghttp3/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig \
    LDFLAGS="-Wl,-rpath,/opt/openssl/lib:/opt/ngtcp2/lib:/opt/nghttp3/lib" \
    ./configure \
        --prefix=/opt/curl \
        --with-openssl=/opt/openssl \
        --with-nghttp2 \
        --with-ngtcp2=/opt/ngtcp2 \
        --with-nghttp3=/opt/nghttp3 \
        --with-zlib \
        --with-brotli \
        --with-zstd && \
    make -j$(nproc) && \
    make install


RUN ldconfig


RUN mkdir -p \
    /results/raw \
    /results/pcaps \
    /results/csv \
    /results/figures \
    /experiments

WORKDIR /experiments

CMD ["tail", "-f", "/dev/null"]