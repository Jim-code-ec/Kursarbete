

#Kontrollera och aktivera Windows Firewall för alla profiler (Domain, Private, Public) med strikta regler (t.ex. tillåt endast RDP och HTTPS).


#Verifiera att Windows Defender är aktivt och uppdaterat; starta en fullständig skanning och logga resultat om det inte är uppdaterat.


#Lista alla användare i Administrators-gruppen, jämför mot en approved_users.txt, ta bort icke-godkända användare och inaktivera konton som inte använts på 90 dagar.


#Kontrollera och inaktivera osäkra protokoll (t.ex. SMBv1) via registerändringar.


#Sök efter och inaktivera onödiga tjänster (t.ex. Telnet, FTP) samt stoppa dem om de körs.


#Kontrollera diskutnyttjande och flytta temporära filer till en arkivmapp om ledigt utrymme är under 15 %.


#Aktivera och konfigurera BitLocker på systemdisken om det inte redan är aktiverat (förutsätter TPM).


#Logga alla åtgärder och resultat till security_hardening_$(Get-Date -Format 'yyyyMMdd').log.

