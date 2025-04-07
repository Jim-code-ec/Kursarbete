#!/bin/bash

# Skript av Jim, 2 april 2025 - Ett skript för att analysera loggfiler och generera en rapport

#Sökväg till loggfilen som ska analyseras
LOG_FILE="/var/log/syslog"

#Fil där analysrapporterna sparas
REPORT_FILE="log_report.txt"

#Läser användarinput för att bestämma hur många rader som ska analyseras
echo "Ange max antal rader som ska analyseras: "
read MAX_LINES

#Kontrollerar om loggfilen finns och är läsbar
if [! -r "$LOG_FILE"];
then echo "Loggilen hittades inte!" exit 1
fi

#Validerar att MAX_LINES är ett positivt heltal
if ! [[ "$MAX_LINES" =~ ^[0-9]+$ ]] || [ "$MAX_LINES" -le 0 ]; then
echo "Ogiltigt antal rader, ange ett positivt heltal!"; exit 1
fi

#Loopar igenom de första MAX_LINES raderna i loggfilen
head -n "$MAX_LINES" "$LOG_FILE" | while read -r line; do

ERROR_COUNT=0
ERROR_COUNT=$((ERROR_COUNT + $(echo "$line" | grep -c "error")))
done

#Funktion för att generera en rapport baserat på logganalysen
generate_report(){
> "$REPORT_FILE"
echo "Logganalysrapport - $(date)" >> "$REPORT_FILE"
echo "Antal felmeddelande: $ERROR_COUNT" >> "$REPORT_FILE"
}

generate_report
# Visar en sammanfattning av analysen för användaren
echo "Analysen är klar. $ERROR_COUNT fel hittades. Rapport sparad i $REPORT_FILE."