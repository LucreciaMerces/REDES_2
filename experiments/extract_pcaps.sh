#!/bin/bash

OUT="/results/csv"
mkdir -p "$OUT"

for SCENARIO in scenario_a_udp scenario_b_http scenario_c_quic; do

    OUTPUT="$OUT/${SCENARIO}_pcap_summary.csv"

    echo "filename,raw_bytes,packet_count" > "$OUTPUT"

    echo "Processando $SCENARIO..."

    for FILE in /results/pcaps/$SCENARIO/*.pcapng; do

        NAME=$(basename "$FILE")

        DATA=$(tshark -r "$FILE" -T fields -e frame.len 2>/dev/null |
            awk '{bytes += $1; packets++} END {print bytes "," packets}')

        echo "$NAME,$DATA" >> "$OUTPUT"

        echo "OK: $NAME"
    done
done

echo "================================"
echo "FINALIZADO"
echo "================================"