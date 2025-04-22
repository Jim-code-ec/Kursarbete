#!/bin/bash

# Skapat av: Nya Grupp 2, April 2025
# =============================
# Loggövervakning av säkerhetsloggar
# Övervakar /var/log/auth.log och /var/log/syslog
# Övervakar händelser för de senaste 24 timmarna 
### ---------------------------------------------------------###


# Tidsformat för senaste 24h
SINCE_DATE=$(date --date="24 hours ago" +"%b %e")
# Loggfiler som ska övervakas
LOGFILES="/var/log/auth.log /var/log/syslog"
BACKUP_DIR="/backup/logs"
BACKUP_NAME=log_backup_$(date +%Y%m%d).tar.gz
BACKUP_DAYS=7 #Antal dagar att behålla loggar
# Skapa rapport med dagens datum som ständigt uppdateras
# Rapporten kommer att sparas i /tmp-katalogen
REPORT_FILE="security_report_$(date +%Y%m%d).txt"
SECURITY_LOG="/var/log/security_actions.log"
ADMIN_EMAIL="jim.nilsson@utb.ecutbildning.se"
TMP_FILE=$(mktemp)
HOG_RISK_IPS=$(grep "Hög risk:" "$REPORT_FILE" | awk '{print $3}')
 

set -e #Avsluta vid fel
set -u #Fel om odefinierade variable används
trap 'echo "Skript avbrutet!"; rm -f "$TMP_FILE"; exit 1' INT TERM EXIT

#Sök efter mönster som "Failed password", "Invalid user", "Accepted password" och "session opened" över de senaste 24 timmarna.
grep -E 'Failed password|Invalid user|Accepted password|Session opened' $LOGFILES | grep -E "$SINCE_DATE" >> "$TMP_FILE"


#Räkna förekomster per IP och användarnamn; flagga IP:n med över 20 misslyckade försök eller icke-existerande användare som "hög risk".
#Skapa statistik för IP-adresser
echo "Statistik per IP:" >> "$REPORT_FILE"
grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' "$TMP_FILE" | sort | uniq -c | sort -nr >> "$REPORT_FILE"

#Flagga IP:n som "Hög risk" om mer än 20 misslyckade försök
echo "IP:er med hög risk (över 20 misslyckade försök):" >> "$REPORT_FILE"
awk '$1 > 20 && $2 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {print "Hög risk:", $2}' "$TMP_FILE" | sort | uniq >> "$REPORT_FILE"

#Skapa statistik per användarnamn
echo "Statistik per användarnamn:" >> "$REPORT_FILE"
awk '/for/ {print $(NF-1)}' "$TMP_FILE" | sort | uniq -c | sort -nr >> "$REPORT_FILE"

#Visa statistik för användarnamn
#Skriv till rapporten om användaren är icke-existerande
echo "Användarnamn som inte finns:" >> "$REPORT_FILE"
grep "Invalid user" "$TMP_FILE" | sed -n 's/.*Invalid user \([^ ]*\).*/\1/p' | sort | uniq | while read -r username; do
    if ! id "$username" &>/dev/null; then # Skriv till rapporten om användaren är icke-existerande
        echo "HÖG RISK: '$username'" >> "$REPORT_FILE"
    fi
done

#Generera en rapport (security_report_$(date +%Y%m%d).txt) med tidpunkter, IP-adresser, användarnamn, händelsetyper och risknivåer.
echo "Detaljer per händelse (IP, användarnamn, händelsetyp, tidpunkt):" >> "$REPORT_FILE"
grep -E 'Failed password|Invalid user|Accepted password|Session opened' "$TMP_FILE" | awk '{print $1, $2, $3, $4, $5, $6, $7, $8}' >> "$REPORT_FILE" #Ändra print $1 osv till rätt

echo "Rapport skapad på $(date)" >> "$REPORT_FILE"

#Skicka rapporten via e-post till en administratör med mail-kommandot (förutsätter att mailutils är installerat på Ubuntu).
#Skickar ett email med namnet Security Report $(date +%Y%m%d) till Admin
mail -s "Security Report $(date +%Y%m%d)" $ADMIN_EMAIL < "$REPORT_FILE"

#Blockera "hög risk"-IP:n med ufw (Ubuntu Firewall) och logga åtgärden i /var/log/security_actions.log.
#Skapar /var/log/security_actions.log om den inte finns
if [ ! -f "$SECURITY_LOG" ]; then
    touch "$SECURITY_LOG"
fi

for IP in $HOG_RISK_IPS; do
    if ufw deny from "$IP"; then
        echo "$(date) - Blockerat IP: $IP med ufw" >> "$SECURITY_LOG"
    else
        echo "$(date) - Misslyckades med att blockera IP: $IP" >> "$SECURITY_LOG"
    fi
done

#Komprimera och arkivera analyserade loggar till /backup/logs/ med tar, radera original efter arkivering om äldre än 7 dagar.
#Skapar backup mappen om den inte finns
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Backupkatalogen finns inte. Skapar den nu..."
    mkdir -p "$BACKUP_DIR"
fi

#Komprimera och arkivera
tar -czvf "$BACKUP_DIR/$BACKUP_NAME" $LOGFILES

for LOG in $LOGFILES; do
    if [ -f "$LOG" ] && find "$LOG" -mtime +"$BACKUP_DAYS" -print -quit | grep -q .; then
        echo "Tar bort: $LOG"
        rm -f "$LOG"
        echo "$(date '+%F %T') - Raderade gammal loggfil: $LOG" >> "$SECURITY_LOG"
    fi
done

 rm -f "$TMP_FILE"