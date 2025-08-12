
# Förstärka Koncepten
# Loopar och if
ports = [80, 23, 443]
for port in ports:
    if port == 23:
        print("Port 23 Hittad")
    else:
        print("Port 23 inte Öppen")

# Tidshantering
import time
# time.strftime = Nutidens format
print("Nu är det:", time.strftime("%Y-%m-%d %H:%M:%S.%f"))
# få skriptet att vila
time.sleep(20)

# Läsa rad för rad
import os
log_file = "C:\\Logs\\network_traffic.log"
if os.path.exists(log_file):
    with open(log_file, "r") as file:
        for line in file:
            print("Hittade rad:", line.strip())
else:
    print("Loggfilen finns inte")

# Räkna med ordböcker
my_counts = {}
ip = "192.168.1.100"
if ip in my_counts:
    my_counts[ip] = my_counts[ip] + 1
else:
    my_counts[ip] = 1

# Skicka mail -> importera smtplib
import smtplib
try:
    server = smtplib.SMTP("smtp.gmail.com", 587)
    server.starttls()
    server.login("test@gmail.com", "gmail-lösen")
    server.sendmail("test@gmail.com", "admin@gmail.com", "Subject: Varning\n\nKonstig port hittad")
    server.quit()
    print("Epost skickat!")
except:
    print("Kunde inte skicka e-post!")

# CSV-funktionalitet
import csv
ips = ["192.168.10.100", "192.168.10.101"]
with open("C:\\Logs\\report.csv", "w") as file:
    file.write("IP\n")
    for ip in ips:
        file.write(ip + "\n")
print("Sparade IP-addresser i CSV-rapporten")

# Köra kommandon via Python på ert system
import subprocess
try:
    result = subprocess.run(["dir", "C:\\Logs"], capture_output=True, text=True)
    print("Följande filer finns i Logs: ", result.stdout)
except:
    print("Kunde inte köra kommandot")

# While -> Köra saker flera gånger
count = 6
while count > 0:
    print("Kollar Loggen, Försök Kvar:", count)
    time.sleep(10)
    count = count - 1
print("Loggar kontrollerade 6 gånger")