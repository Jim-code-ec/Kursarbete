#!/bin/bash

# Skapat av: Nya Grupp 2, April 2025
# =============================
# Loggövervakning av säkerhetsloggar
# Övervakar /var/log/auth.log och /var/log/syslog
# Övervakar händelser för de senaste 24 timmarna 
### ---------------------------------------------------------###


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
trap 'echo "Skript avbrutet!"; rm -f "$TMP_FILE"; exit 1' INT TERM
trap 'echo "Skript Klart!"; rm -f "$TMP_FILE"; exit 1' EXIT

#Sök efter mönster som "Failed password", "Invalid user", "Accepted password" och "session opened" över de senaste 24 timmarna.
echo "Söker efter "Failed password", "Invalid user", "Accepted password" och "session opened" över de senaste 24 timmarna."
awk "(/Failed password/ || /Invalid user/ || /Accepted password/ || /Session opened/) && \$0 >= \"$(date --date='24 hours ago' '+%Y-%m-%d %H:%M:%S')\"" $LOGFILES >> "$TMP_FILE"
echo "Klar"

if [ ! -f "$REPORT_FILE" ]; then
    echo "security_report_$(date +%Y%m%d).txt finns inte. Skapar den nu..."
    touch "$REPORT_FILE"
    echo "Klar"
fi

#Räkna förekomster per IP och användarnamn; flagga IP:n med över 20 misslyckade försök eller icke-existerande användare som "hög risk".
echo "Räknar IP adresser"
echo "Statistik per IP:" > "$REPORT_FILE"
grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' "$TMP_FILE" | sort | uniq -c | sort -nr >> "$REPORT_FILE"
echo "Klar"

echo "Flaggar IP:n som "Hög risk" om mer än 20 misslyckade försök"
echo "IP:er med hög risk (över 20 misslyckade försök):" >> "$REPORT_FILE"
grep "Failed password" "$TMP_FILE" | awk '{for(i=1;i<NF;i++) if ($i=="from") print $(i+1)}' | sort | uniq -c | awk '$1 > 20 {print "Hög risk:", $2}' >> "$REPORT_FILE"
echo "Klar"

echo "Räknar användarnamn"
echo "Statistik per användarnamn:" >> "$REPORT_FILE"
awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i-1)}' "$TMP_FILE" | sort | uniq -c | sort -nr >> "$REPORT_FILE"
echo "Klar"

#Om användarnamn inte finns är den Hög Risk
echo "Skriv till rapporten om användaren är icke-existerande"
echo "Användarnamn som inte finns:" >> "$REPORT_FILE"
grep "Invalid user" "$TMP_FILE" | sed -n 's/.*Invalid user \([^ ]*\).*/\1/p' | sort | uniq | while read -r username; do
    if ! id "$username"; then # Skriv till rapporten om användaren är icke-existerande
        echo "HÖG RISK: '$username'" >> "$REPORT_FILE"
    fi
done
echo "Klar"

#Generera en rapport (security_report_$(date +%Y%m%d).txt) med tidpunkter, IP-adresser, användarnamn, händelsetyper och risknivåer.
echo "Genererar en rapport"
echo "Detaljer per händelse (IP, användarnamn, händelsetyp, tidpunkt):" >> "$REPORT_FILE"
grep -E 'Failed password|Invalid user|Accepted password|Session opened' "$TMP_FILE" | awk '{print $0}' >> "$REPORT_FILE"

echo "Rapport skapad på $(date)" >> "$REPORT_FILE"
echo "Klar"

#Skicka rapporten via e-post till en administratör med mail-kommandot (förutsätter att mailutils är installerat på Ubuntu).
#Skickar ett email med namnet Security Report $(date +%Y%m%d) till Admin
echo "Skickar email till admin"
mail -s "Security Report $(date +%Y%m%d)" "$ADMIN_EMAIL" < "$REPORT_FILE"
echo "Klar"

#Blockera "hög risk"-IP:n med ufw (Ubuntu Firewall) och logga åtgärden i /var/log/security_actions.log.
#Skapar /var/log/security_actions.log om den inte finns
if [ ! -f "$SECURITY_LOG" ]; then
    echo "security_actions.log finns inte. Skapar den nu..."
    touch "$SECURITY_LOG"
    echo "Klar"
fi

echo "Blockerar Hög Risk IP"
for IP in $HOG_RISK_IPS; do
    if ufw deny from "$IP"; then
        echo "$(date) - Blockerat IP: $IP med ufw" >> "$SECURITY_LOG"
    else
        echo "$(date) - Misslyckades med att blockera IP: $IP" >> "$SECURITY_LOG"
    fi
done
echo "Klar"

#Komprimera och arkivera analyserade loggar till /backup/logs/ med tar, radera original efter arkivering om äldre än 7 dagar.
#Skapar backup mappen om den inte finns
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Backupkatalogen finns inte. Skapar den nu..."
    mkdir -p "$BACKUP_DIR"
    echo "Klar"
fi

#Komprimera och arkivera
echo "Skapar Backup"
tar --ignore-failed-read -czvf "$BACKUP_DIR/$BACKUP_NAME" $LOGFILES
echo "Klar"

echo "Tar bort äldre än 7 dagar loggfiler"
for LOG in $LOGFILES; do
    if [ -f "$LOG" ] && find "$LOG" -mtime +"$BACKUP_DAYS" | grep -q .; then
        echo "Tar bort: $LOG"
        rm -f "$LOG"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Raderade gammal loggfil: $LOG" >> "$SECURITY_LOG"
    fi
done
echo "Klar"

echo "Tar bort $TMP_FILE"
rm -f "$TMP_FILE"
echo "Klar"

exit 0