# Skapat av: Jim Nilsson, April 2025
# =============================
# Loggövervakning av nätverkstrafik
# Övervakar nätverkstrafikloggar i realtid
# Identifierar misstänkt aktivitet och blockerar hotfulla IP-adresser
# Genererar rapporter för analyserad trafik
### ---------------------------------------------------------###

import time
import smtplib
import csv
import subprocess

#Konfiguration
LOG_FILE = "network_traffic.log"

FROM_EMAIL = "test@gmail.com"
TO_EMAIL = "admin@gmail.com"
PASSWORD_EMAIL = "lösenord"

def send_email_alert(subject, message):
    try:
        server = smtplib.SMTP("smtp.gmail.com", 587)
        server.starttls()
        server.login(FROM_EMAIL, PASSWORD_EMAIL)
        EMAIL_BODY = f"Subject: {subject}\n\n{message}"
        server.sendmail(FROM_EMAIL, TO_EMAIL, EMAIL_BODY)
        server.quit()
        print("Skickat epost!")
    except Exception as e:
        print(f"Misslyckades att skicka e-post: {e}")

def block_ip(ip, blocked_ips):
    try:

        ip = ip.strip()  #Ta bort eventuella extra mellanslag

        if ip in blocked_ips:
            print(f"IP {ip} är redan blockerad.")
            return
        
        #Kör UFW-kommando för att blockera IP-adressen
        subprocess.run(["sudo", "ufw", "deny", "from", ip], check=True)
        print(f"IP {ip} blockerad via UFW.")
        blocked_ips.append(ip)
    except subprocess.CalledProcessError as e:
        print(f"Fel vid blockerande av IP {ip}: {e}")


def analyze_traffic():
    ip_connections = {}  #Antal anslutningar per IP
    port_connections = {}  #Portar som flaggades
    destination_volume = {}  #Antal kopplingar till destinationer

    flagged_entries = [] #Lista för flaggade poster
    blocked_ips = [] #Lista för blockerade IP-adresser

    with open(LOG_FILE, mode='r') as file:
        for line in file:
            #Dela upp raden baserat på ett kommatecken
            parts = line.strip().split(",")
            
            #Kontrollera om vi har rätt antal fält
            if len(parts) == 5:
                timestamp, source_ip, dest_ip, port, protocol = parts
                
                #Uppdatera antal anslutningar per IP
                if source_ip not in ip_connections:
                    ip_connections[source_ip] = 0
                ip_connections[source_ip] += 1
                
                #Kontrollera om porten är ovanlig (under 1024, men inte 22, 80 eller 443)
                if int(port) < 1024 and int(port) not in {22, 80, 443}:
                    if source_ip not in port_connections:
                        port_connections[source_ip] = []
                    port_connections[source_ip].append(int(port))
                
                #Uppdatera volymen till destinationen
                if dest_ip not in destination_volume:
                    destination_volume[dest_ip] = 0
                destination_volume[dest_ip] += 1
            else:
                print(f"Felaktig rad i loggen: {line}")
    
    #Beräkna genomsnittlig anslutningsfrekvens
    total_connections = 0
    num_ips = len(ip_connections)

    #Flagga IP:n med över 100 anslutningar
    for ip, count in ip_connections.items():
        total_connections += count
        if count > 100:

            alert_msg = f"IP {ip} har {count} anslutningar (över 100)."
            print(f"Flaggad IP: {alert_msg}")
            send_email_alert("Misstänkt nätverkstrafik", alert_msg)

            block_ip(ip, blocked_ips)

            flagged_entries.append({
                "Typ": "Hög anslutningsfrekvens",
                "IP": ip,
                "Detaljer": f"{count} anslutningar"
            })

    if num_ips > 0:
        avg_connections = total_connections / num_ips
    else:
        avg_connections = 0
    
    #Flagga ovanliga portar
    for ip, ports in port_connections.items():
        if len(ports) > 0:

            alert_msg = f"IP {ip} använder ovanliga portar: {set(ports)}"
            print(f"Flaggad IP: {alert_msg}")
            send_email_alert("Ovanliga portar upptäckta", alert_msg)

            block_ip(ip, blocked_ips)

            flagged_entries.append({
                "Typ": "Ovanliga portar",
                "IP": ip,
                "Detaljer": f"Portar: {sorted(set(ports))}"
            })
    
    #Flagga om volymen till destinationen är hög
    for dest_ip, volume in destination_volume.items():
        if volume > 100:
                
            alert_msg = f"Hög trafik till destination {dest_ip}: {volume} anslutningar."
            print(alert_msg)
            send_email_alert("Hög destinationstrafik", alert_msg)

            flagged_entries.append({
                "Typ": "Hög destinationstrafik",
                "IP": dest_ip,
                "Detaljer": f"{volume} anslutningar"
            })

    #Lägg till genomsnittlig anslutningsfrekvens till rapporten
    flagged_entries.append({
        "Typ": "Genomsnittlig anslutningsfrekvens",
        "IP": "N/A",
        "Detaljer": f"{avg_connections:.2f} anslutningar per IP"
    })

    for blocked_ip in blocked_ips:
        flagged_entries.append({
            "Typ": "Blockerad IP",
            "IP": blocked_ip,
            "Detaljer": "Blockerad via UFW"
        })

    #Skriv ut flaggade poster till CSV-fil
    with open("attack_report.csv", 'w') as csv_file:
        fieldnames = ["Typ", "IP", "Detaljer"]
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        for entry in flagged_entries:
            writer.writerow(entry)


#Kör analysen var femte minut
while True:
    analyze_traffic()
    time.sleep(300)  #Vänta 5 minuter
