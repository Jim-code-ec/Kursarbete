#!/bin/bash

# Skapat av: Jim, April 2025

AUTH_LOG="/var/log/auth.log"
SYS_LOG="/var/log/syslog"
BACKUP_DIR="/backup/logs"
REPORT_FILE="security_report_$(date +%Y%m%d).txt"
SECURITY_LOG="/var/log/security_actions.log"
ADMIN_EMAIL="admin@admin.se"
TMP_FILE="/tmp/security_temp.log"

set -e #Avsluta vid fel
set -u #Fel om odefinierade variablee används
trap 'echo "Skript avbrutet!"; rm -f "$TMP_FILE"; exit 1' INT TERM EXIT

#Sök efter mönster som "Failed password", "Invalid user", "Accepted password" och "session opened" över de senaste 24 timmarna.
grep -E 'Failed password|Invalid user|Accepted password|Session opened' $AUTH_LOG $SYS_LOG | grep "$(date --date='24 hours ago' '+%b %d')" > $SECURITY_LOG


#Räkna förekomster per IP och användarnamn; flagga IP:n med över 20 misslyckade försök eller icke-existerande användare som "hög risk".


#Generera en rapport (security_report_$(date +%Y%m%d).txt) med tidpunkter, IP-adresser, användarnamn, händelsetyper och risknivåer.


#Skicka rapporten via e-post till en administratör med mail-kommandot (förutsätter att mailutils är installerat på Ubuntu).


#Blockera "hög risk"-IP:n med ufw (Ubuntu Firewall) och logga åtgärden i /var/log/security_actions.log.


#Komprimera och arkivera analyserade loggar till /backup/logs/ med tar, radera original efter arkivering om äldre än 7 dagar.
