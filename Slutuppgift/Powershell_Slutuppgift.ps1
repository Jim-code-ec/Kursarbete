# Skapat av: Jim Nilsson, April 2025
# =============================
# Skriptet utför säkerhetshärdning genom att kontrollera användare, Windows Defender, 
# brandväggsinställningar, SMBv1, tjänster, diskutrymme och BitLocker.
# Loggar alla åtgärder till en fil och hanterar temporära filer genom att flytta dem till en arkivmapp vid behov.
### ---------------------------------------------------------###

$WinStatus=Get-Service -Name WinDefend
$UpdateStatus=Get-MpComputerStatus

$approvedUsers=Get-Content -Path "C:\approved_users.txt"
$adminGroup=Get-LocalGroupMember -Group "Administrators"
$90Days=(Get-Date).AddDays(-90)
$users=Get-LocalUser | Select-Object Name, Enabled, LastLogon

$SMB1Reg="HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
$SMB1=Get-ItemProperty -Path $SMB1Reg -Name SMB1 -ErrorAction SilentlyContinue
$servicesToDisable=@("TlntSvr", "FTPSVC")

$archiveFolder="C:\TempFolder"
$tempFolder=$env:TEMP

$disk=Get-Volume -DriveLetter C
$freePercent=($disk.SizeRemaining / $disk.Size) * 100
$BitLockerStatus=Get-BitLockerVolume -MountPoint "C:"

$logFile="C:\security_hardening_$(Get-Date -Format 'yyyyMMdd').log"

#Funktion: Loggning
function Log { 
    param (
        [string]$msg
    ) 
    Write-Host $msg 
    Add-Content -Path $logFile -Value "$((Get-Date).ToString('u')) - $msg" 
} 

if (-not (Test-Path $logFile)) {
    New-Item -Path $logFile -ItemType File -Force
    Log "Filen har skapats"
}

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

Log "Branväggen är på, blockerar alla inkommande trafik och tillåter all utgående trafik, RDP och HTTPS tillåten på port 3389 och 443 respektive"

#Verifiera att Windows Defender är aktivt och uppdaterat; starta en fullständig skanning och logga resultat om det inte är uppdaterat.
#Kollar om Windows Defender är på, sätts på om det inte är
if ($WinStatus.Status -ne 'Running') {
    Log "Windows Defender är inte aktivt"
    Start-Service -Name WinDefend
    Log "Windows Defender har startats"
} else {
   Log "Windows Defender är redan på"
}

#Uppdaterar WinDef och skannar datorn.
if ($UpdateStatus.AntispywareSignatureAge -gt 1 -or $UpdateStatus.AntivirusSignatureAge -gt 1) {
    Log "Ej uppdaterad, uppdaterar och startar skanning"
    Update-MpSignature
    Log "Uppdatering klar"

    Start-MpScan -ScanType QuickScan | Out-File -FilePath "C:\WindowsDefenderScanLog.txt"
    Log "Skanning klar, resultat finns i C:\WindowsDefenderScanLog.txt"
} else {
    Log "Behöver inte uppdatera eller skanna"
}

#Lista alla användare i Administrators-gruppen, jämför mot en approved_users.txt, ta bort icke-godkända användare och inaktivera konton som inte använts på 90 dagar.
#Jämför och tar bort icke-godkända användare
foreach ($user in $adminGroup) {
    if ($user.Name -notin $approvedUsers) {
        Log "Ta bort användare från Administrators-gruppen: $($user.Name)"
        Remove-LocalGroupMember -Group "Administrators" -Member $user
        Log "Tagit bort admin: $($user.Name)"
    } else {
        Log "Inget behövs göra för admin: $($user.Name)"
    }
}

#Tar bort användare som inte har använts på 90 dagar
foreach ($user in $users) {
    $lastLogon = $user.LastLogon
    if ($lastLogon -lt $90Days -and $user.Enabled) {
        Log "Inaktiverar konto för användare: $($user.Name)"
        Disable-LocalUser -Name $user.Name
        Log "Tagit bort: $($user.Name)"
    } else {
        Log "Inget behövs göra för: $($user.Name)"
    }
}

#Kontrollera och inaktivera osäkra protokoll (t.ex. SMBv1) via registerändringar.
if ($SMB1.SMB1 -eq 0) {
    Log "SMBv1 är redan inaktiverat"
} else {
    Log "SMBv1 inaktiveras"
    Set-ItemProperty -Path $SMB1Reg -Name SMB1 -Value 0
    Log "SMBv1 har inaktiverats, starta om datorn"
}

#Sök efter och inaktivera onödiga tjänster (t.ex. Telnet, FTP) samt stoppa dem om de körs.
foreach ($service in $servicesToDisable) {
    $serviceName = Get-Service -Name $service -ErrorAction SilentlyContinue
    if ($serviceName) {
        if ($serviceName.Status -eq 'Running') {
            Log "Stoppar tjänsten $service"
            Stop-Service -Name $service -Force
            Log "Klart"
        }
        Log "Inaktiverar tjänsten $service"
        Set-Service -Name $service -StartupType Disabled
        Log "Klart"
    } else {
        Log "Tjänsten $service finns inte på systemet"
    }
}

#Kontrollera diskutnyttjande och flytta temporära filer till en arkivmapp om ledigt utrymme är under 15 %.
#Skapa arkivmapp om den inte finns
if (-not (Test-Path $archiveFolder)) {
    New-Item -ItemType Directory -Path $archiveFolder
    Log "Skapat TempFolder"
}
if ($freePercent -lt 15) {
    Log "Mindre än 15 % ledigt - flyttar temporära filer"
    Move-Item -Path "$tempFolder\*" -Destination $archiveFolder -Force
    Log "Alla filer flyttats till $archiveFolder"
} else {
    Log "Tillräckligt med utrymme - inga åtgärder vidtas."
}

#Aktivera och konfigurera BitLocker på systemdisken om det inte redan är aktiverat (förutsätter TPM).
if ($BitLockerStatus.ProtectionStatus -eq "Off") {
    Log "BitLocker är inte på, sätter på nu."
    Enable-BitLocker -MountPoint "C:" -EncryptionMethod Aes256 -RecoveryKeyPath "E:\" -RecoveryKeyProtector
    Log "BitLocker är nu på."
} else {
    Log "Bitlocker var redan på."
}


#Logga alla åtgärder och resultat till security_hardening_$(Get-Date -Format 'yyyyMMdd').log.

