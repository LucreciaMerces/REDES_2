#!/bin/bash

set -euo pipefail

SERVER="server"
INTERFACE="eth0"

RAW_DIR="/results/raw/scenario_c_quic"
PCAP_DIR="/results/pcaps/scenario_c_quic"

REPETITIONS=10
OBJECTS=50
OBJECT_SIZE=102400
TOTAL_BYTES=$((OBJECTS * OBJECT_SIZE))

PROTOCOLS=("http2" "http3")

mkdir -p "$RAW_DIR"
mkdir -p "$PCAP_DIR"

cleanup() {
    if [ -n "${TSHARK_PID:-}" ]; then
        kill "$TSHARK_PID" 2>/dev/null || true
        wait "$TSHARK_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

echo "=========================================="
echo " CENARIO C - REDE ADVERSA / QUIC"
echo "=========================================="
echo "RTT alvo: >= 100 ms"
echo "Perda artificial configurada: 3%"
echo "Objetos por repeticao: $OBJECTS"
echo "Tamanho por objeto: $OBJECT_SIZE bytes"
echo "Bytes uteis por repeticao: $TOTAL_BYTES"
echo "Repeticoes por protocolo: $REPETITIONS"
echo "Protocolos: HTTP/2 e HTTP/3"
echo "=========================================="

echo
echo "=========================================="
echo " TESTE PRINCIPAL - 50 OBJETOS CONCORRENTES"
echo "=========================================="

for PROTOCOL in "${PROTOCOLS[@]}"; do

    case "$PROTOCOL" in
        http2)
            CURL_PROTOCOL="--http2"
            CAPTURE_FILTER="tcp port 443"
            ;;

        http3)
            CURL_PROTOCOL="--http3-only"
            CAPTURE_FILTER="udp port 443"
            ;;
    esac

    echo
    echo "------------------------------------------"
    echo " PROTOCOLO: $PROTOCOL"
    echo "------------------------------------------"

    for REP in $(seq -w 1 "$REPETITIONS"); do

        RESULT_FILE="${RAW_DIR}/${PROTOCOL}_concurrent_rep_${REP}.csv"
        PCAP_FILE="${PCAP_DIR}/${PROTOCOL}_concurrent_rep_${REP}.pcapng"

        echo "[$PROTOCOL] Repeticao $REP/$REPETITIONS"

        rm -f "$RESULT_FILE" "$PCAP_FILE"

        tshark \
            -i "$INTERFACE" \
            -f "$CAPTURE_FILTER" \
            -w "$PCAP_FILE" \
            >/dev/null 2>&1 &

        TSHARK_PID=$!

        sleep 0.3

        START_NS=$(date +%s%N)

        curl \
            -k \
            $CURL_PROTOCOL \
            --parallel \
            --parallel-max 50 \
            -sS \
            -o /dev/null \
            "https://${SERVER}/objects/object_[01-50].bin"

        END_NS=$(date +%s%N)

        FCT=$(python3 -c "print(($END_NS - $START_NS) / 1000000000)")
        GOODPUT=$(python3 -c "print(($TOTAL_BYTES * 8) / $FCT / 1000000)")

        echo "protocol,rep,fct_seconds,useful_bytes,goodput_mbps" > "$RESULT_FILE"
        echo "$PROTOCOL,$REP,$FCT,$TOTAL_BYTES,$GOODPUT" >> "$RESULT_FILE"

        sleep 0.2

        kill "$TSHARK_PID" 2>/dev/null || true
        wait "$TSHARK_PID" 2>/dev/null || true
        unset TSHARK_PID

        if [ ! -s "$RESULT_FILE" ]; then
            echo "ERRO: resultado vazio: $RESULT_FILE"
            exit 1
        fi

        if [ ! -s "$PCAP_FILE" ]; then
            echo "ERRO: captura vazia: $PCAP_FILE"
            exit 1
        fi

        echo "FCT=${FCT}s GOODPUT=${GOODPUT}Mbps"
        echo "OK"

        sleep 0.3
    done
done

echo
echo "=========================================="
echo " TESTE DE RECONEXAO"
echo "=========================================="

for PROTOCOL in "${PROTOCOLS[@]}"; do

    case "$PROTOCOL" in
        http2)
            CURL_PROTOCOL="--http2"
            ;;
        http3)
            CURL_PROTOCOL="--http3-only"
            ;;
    esac

    RECONNECT_FILE="${RAW_DIR}/${PROTOCOL}_reconnection.csv"

    echo "protocol,rep,time_connect,time_appconnect,time_starttransfer,time_total,http_version" > "$RECONNECT_FILE"

    echo
    echo "Reconexao: $PROTOCOL"

    for REP in $(seq -w 1 "$REPETITIONS"); do

        echo "[$PROTOCOL][reconnect] $REP/$REPETITIONS"

        RESULT=$(curl \
            -k \
            $CURL_PROTOCOL \
            -o /dev/null \
            -sS \
            -w "%{time_connect},%{time_appconnect},%{time_starttransfer},%{time_total},%{http_version}" \
            "https://${SERVER}/objects/object_01.bin")

        echo "$PROTOCOL,$REP,$RESULT" >> "$RECONNECT_FILE"

        sleep 0.2
    done
done

echo
echo "=========================================="
echo " CENARIO C CONCLUIDO"
echo "=========================================="
echo "Resultados: $RAW_DIR"
echo "Capturas: $PCAP_DIR"