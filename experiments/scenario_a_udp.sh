#!/bin/bash

set -euo pipefail

SERVER="server"
INTERFACE="eth0"

RAW_DIR="/results/raw/scenario_a_udp"
PCAP_DIR="/results/pcaps/scenario_a_udp"

REPETITIONS=10
DURATION=3

RATES=("10M" "50M" "100M" "250M" "500M")

mkdir -p "$RAW_DIR"
mkdir -p "$PCAP_DIR"

cleanup() {
    if [ -n "${TSHARK_PID:-}" ]; then
        kill "$TSHARK_PID" 2>/dev/null || true
        wait "$TSHARK_PID" 2>/dev/null || true
    fi

    tc qdisc del dev "$INTERFACE" root 2>/dev/null || true
}

trap cleanup EXIT INT TERM

echo "=========================================="
echo " CENARIO A - UDP"
echo "=========================================="
echo "Servidor: $SERVER"
echo "Interface: $INTERFACE"
echo "Repeticoes por taxa: $REPETITIONS"
echo "Duracao por repeticao: ${DURATION}s"
echo "Taxas: ${RATES[*]}"
echo "=========================================="

tc qdisc del dev "$INTERFACE" root 2>/dev/null || true


tc qdisc add dev "$INTERFACE" root netem delay 1ms loss 0%

echo
echo "Configuracao NetEm:"
tc qdisc show dev "$INTERFACE"

echo
echo "Validacao do RTT antes dos testes:"
ping -c 10 "$SERVER"

echo
echo "=========================================="
echo " INICIO DOS TESTES OFICIAIS"
echo "=========================================="

for RATE in "${RATES[@]}"; do

    echo
    echo "------------------------------------------"
    echo " TAXA: $RATE"
    echo "------------------------------------------"

    for REP in $(seq -w 1 "$REPETITIONS"); do

        JSON_FILE="${RAW_DIR}/udp_${RATE}_rep_${REP}.json"
        PCAP_FILE="${PCAP_DIR}/udp_${RATE}_rep_${REP}.pcapng"

        echo "[$RATE] Repeticao $REP/$REPETITIONS"

        rm -f "$JSON_FILE" "$PCAP_FILE"

        tshark \
            -i "$INTERFACE" \
            -f "udp port 5201" \
            -w "$PCAP_FILE" \
            >/dev/null 2>&1 &

        TSHARK_PID=$!

        sleep 0.5

        iperf3 \
            -c "$SERVER" \
            -u \
            -b "$RATE" \
            -t "$DURATION" \
            -J \
            > "$JSON_FILE"

        sleep 0.3

        kill "$TSHARK_PID" 2>/dev/null || true
        wait "$TSHARK_PID" 2>/dev/null || true
        unset TSHARK_PID

        if [ ! -s "$JSON_FILE" ]; then
            echo "ERRO: JSON vazio: $JSON_FILE"
            exit 1
        fi

        if [ ! -s "$PCAP_FILE" ]; then
            echo "ERRO: PCAPNG vazio: $PCAP_FILE"
            exit 1
        fi

        echo "OK"

        sleep 0.5

    done
done

tc qdisc del dev "$INTERFACE" root 2>/dev/null || true

echo
echo "=========================================="
echo " CENARIO A CONCLUIDO"
echo "=========================================="
echo "JSON: $RAW_DIR"
echo "PCAPNG: $PCAP_DIR"