# -------------------- Dokumentation
# network_monitor.py -> Enkel detektering av nättrafik
# Skapat av: Ludwig Simonsson Israelsson, Maj, 2025
#
# Syftet:
# Läsa Nätverkslogg
# Flagga vid misstänkt portanvändning
# Räkna IP-anslutningar
# Skicka e-post
# Spara rapport
# Simulera IP-blockering
#
# Kravbild:
# -> Läsa loggfilen med tid, källa, destination, port och protokoll
# -> Flagga anslutningar till port 8080 och/eller IPn med fler än 5 anslutningar
# -> Skicka e-postvarningar vid händelser upptäckta
# -> Spara en CSV-rapport med fynden
# -> Simulera UFW-blockering
# -> Alltingen skall loggas 
# -> Kör i en slinga för att repetera
# ----------------------------------------------

# Modulimportering -----------------------------
import os
import logging
import time
import re
import csv
import smtplib
import subprocess

# Konfigurationen ------------------------------
LOG_DIR = "C\\Logs"
LOG_FILE = os.path.join(LOG_DIR, "monitor.log")
TRAFFIC_LOG = os.path.join(LOG_DIR, "network_traffic.log")
EMAIL_FROM = "test@gmail.com"
EMAIL_TO = "admin@gmail.com"
EMAIL_PASSWORD = "app-lösenord"

# Loggningsfunktioner --------------------------
def setup_logging():
    logging.basicConfig(
        filename=LOG_FILE,
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )

def log_message(level, message):
    if level == "INFO":
        logging.info(message)
    elif level == "WARNING":
        logging.warning(message)
    elif level == "ERROR":
        logging.error(message)

# Validering -----------------------------------
setup_logging()
log_message("INFO", "Startar nätverkskontrollen....")

if not os.path.exists(TRAFFIC_LOG):
    log_message("ERROR", "Loggfilen finns inte!")
    print("ERROR: Loggfilen saknas")
    exit(1)

# Huvudlogik -----------------------------------
try:
    count = 3
    while count > 0:
        connections = {}

        with open(TRAFFIC_LOG, "r") as file:
            for line in file:
                if "8080" in line:
                    message = "Hittat misstänkt port 8080"
                    log_message("WARNING", message)
                    print("WARNING: ", message)

                    try:
                        server = smtplib.SMTP("smtp.gmail.com", 587)
                        server.starttls()
                        server.login(EMAIL_FROM, EMAIL_PASSWORD)
                        server.sendmail(EMAIL_FROM, EMAIL_TO,
                                       "Subject: Nätverksvarning\n\nMisstänkt port 8080 hittad!")
                        server.quit()
                        log_message("INFO", "Skicka e-postvarning")
                        print("Skickat epost!")
                    except:
                        log_message("ERROR", "Kunde inte skicka epost")
                        print("ERROR: Kunde inte skicka epostvarning")
                # Låtsas att filen skriver tid, address
                parts = line.split(",")
                if len(parts) >= 2:
                    ip = parts[1]
                    connections[ip] = connections.get(ip, 0) + 1

                    if connections[ip] > 5:
                        message = "IP " + ip + " har för många anslutningar"
                        log_message("WARNING", message)
                        print("WARNING:", message)
        with open("C:\\Logs\\suspicious_ips.csv", "w") as file:
            file.write("IP, Antal\n")
            for ip, count in connections.items():
                file.write(ip + "," + str(count) + "\n")
        log_message("INFO", "Sparade rapporten")
        print("IP-rapport har sparats på systemet!")

        try:
            result = subprocess.run(["dir", "C:\\Logs"], capture_output=True, text=True)
            log_message("INFO", "Blockerade IP med UFW")
        except:
            log_message("ERROR", "Kunde inte blockera IP")
            print("Kunde inte köra block-kommandot!")

        log_message("INFO", "Klar med en kontroll")
        print("Klar med en kontroll!")
        time.sleep(10)
        count = count - 1
    log_message("INFO", "Loggen kontrollerad tre gånger")

except Exception as e:
    log_message("ERROR", "Något gick fel!")
    exit(1)