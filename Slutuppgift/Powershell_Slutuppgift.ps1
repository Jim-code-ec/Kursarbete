$WinStatus = Get-Service -Name WinDefend
$UpdateStatus = Get-MpComputerStatus | Select-Object AntispywareSignatureAge, AntivirusSignatureAge

#Kontrollera och aktivera Windows Firewall för alla profiler (Domain, Private, Public) med strikta regler (t.ex. tillåt endast RDP och HTTPS).
#Aktivera branvägg för alla profiler
Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True

#Blockera inkommande och tillåt utgående
Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultInboundAction Block
Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultOutboundAction Allow

#Tillåt RDP på port 3389 TCP
New-NetFirewallRule -DisplayName "Allow RDP" -Direction Inbound -Protocol TCP -LocalPort 3389 -Action Allow -Profile Domain,Private,Public

#Tillåt HTTPS på port 443 TCP
New-NetFirewallRule -DisplayName "Allow HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow -Profile Domain,Private,Public


#Verifiera att Windows Defender är aktivt och uppdaterat; starta en fullständig skanning och logga resultat om det inte är uppdaterat.
#Kollar om Windows Defender är på, sätts på om det inte är
if ($WinStatus.Status -ne 'Running') {
    Write-Output "Windows Defender är inte aktivt"
    Start-Service -Name WinDefend
    Write-Output "Windows Defender har startats"
}

#Uppdaterar WinDef och skannar datorn.
if ($UpdateStatus -gt 0) {
    Write-Output "Ej uppdaterad, uppdaterar och startar skanning"
    Update-MpSignature

    Start-MpScan -ScanType QuickScan | Out-File "C:\WindowsDefenderScanLog.txt"
    Write-Output "Skanning klar, resultat finns i C:\WindowsDefenderScanLog.txt"
}

#Lista alla användare i Administrators-gruppen, jämför mot en approved_users.txt, ta bort icke-godkända användare och inaktivera konton som inte använts på 90 dagar.


#Kontrollera och inaktivera osäkra protokoll (t.ex. SMBv1) via registerändringar.


#Sök efter och inaktivera onödiga tjänster (t.ex. Telnet, FTP) samt stoppa dem om de körs.


#Kontrollera diskutnyttjande och flytta temporära filer till en arkivmapp om ledigt utrymme är under 15 %.


#Aktivera och konfigurera BitLocker på systemdisken om det inte redan är aktiverat (förutsätter TPM).


#Logga alla åtgärder och resultat till security_hardening_$(Get-Date -Format 'yyyyMMdd').log.

