#!/bin/bash

set -euo pipefail

SERVER="server"
INTERFACE="eth0"

RAW_DIR="/results/raw/scenario_b_http"
PCAP_DIR="/results/pcaps/scenario_b_http"

REPETITIONS=10

PROTOCOLS=("http1" "http2" "http3")
FILES=("file100M.bin" "file500M.bin")

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
echo " CENARIO B - TCP/HTTP"
echo "=========================================="
echo "RTT alvo: aproximadamente 20 ms"
echo "Perda artificial: 0%"
echo "Repeticoes: $REPETITIONS"
echo "Protocolos: HTTP/1.1 HTTP/2 HTTP/3"
echo "Arquivos: 100 MB e 500 MB"
echo "=========================================="

for FILE in "${FILES[@]}"; do

    if [[ "$FILE" == "file100M.bin" ]]; then
        SIZE="100M"
    else
        SIZE="500M"
    fi

    for PROTOCOL in "${PROTOCOLS[@]}"; do

        echo
        echo "------------------------------------------"
        echo "$PROTOCOL - $SIZE"
        echo "------------------------------------------"

        case "$PROTOCOL" in
            http1)
                CURL_PROTOCOL="--http1.1"
                CAPTURE_FILTER="tcp port 443"
                ;;

            http2)
                CURL_PROTOCOL="--http2"
                CAPTURE_FILTER="tcp port 443"
                ;;

            http3)
                CURL_PROTOCOL="--http3-only"
                CAPTURE_FILTER="udp port 443"
                ;;
        esac

        for REP in $(seq -w 1 "$REPETITIONS"); do

            RESULT_FILE="${RAW_DIR}/${PROTOCOL}_${SIZE}_rep_${REP}.csv"
            PCAP_FILE="${PCAP_DIR}/${PROTOCOL}_${SIZE}_rep_${REP}.pcapng"

            echo "[$PROTOCOL][$SIZE] Repeticao $REP/$REPETITIONS"

            rm -f "$RESULT_FILE" "$PCAP_FILE"

            tshark \
                -i "$INTERFACE" \
                -f "$CAPTURE_FILTER" \
                -w "$PCAP_FILE" \
                >/dev/null 2>&1 &

            TSHARK_PID=$!

            sleep 0.3

            curl \
                -k \
                $CURL_PROTOCOL \
                -o /dev/null \
                -sS \
                -w "%{time_total},%{size_download},%{speed_download},%{http_version}\n" \
                "https://${SERVER}/${FILE}" \
                > "$RESULT_FILE"

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

            echo "OK"

            sleep 0.3

        done
    done
done

echo
echo "=========================================="
echo " CENARIO B CONCLUIDO"
echo "=========================================="
echo "Resultados: $RAW_DIR"
echo "Capturas: $PCAP_DIR"