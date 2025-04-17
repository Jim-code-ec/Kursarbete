#LogMonitor.ps1 - Övervakar loggfiler för misstänkta nyckelord
#Skapats av Jim, April 2025
#Syfte: skanna loggar, logga resultat och varna om problem

#---Konfiguration---
$LogDir="C:\Logs"
$OutputLog="C:\Logs\monitor.log"
$Keywords=@("error", "failed", "warning")

#---Funktioner---
function Write-Log {
    param (
        [Parameter(Mandatory=$true)][string]$Level,
        [Parameter(Mandatory=$true)][string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp [$Level] $Message" | Out-File -FilePath $OutputLog -Append
}

#---Validerig---
Write-Log -Level "INFO" -Message "Startar loggövervakning..."
if (-not (Test-Path $LogDir)){
    Write-Log -Level "ERROR" -Message "Katalogen $Logdir finns inte."
    Write-Error "Katalogen finns inte!"
    exit 1
}

#---Huvudlogik---
try {
    $files = Get-ChildItem -Path $LogDir -File -ErrorAction Stop
    foreach ($file in $files) {
        $content = Get-Content $file.FullName -ErrorAction Stop
        foreach ($line in $content) {
            foreach ($keyword in $Keywords) {
                if ($line -match $keyword) {
                    $message = "Hittade '$keyword' i $($file.Name): $line"
                    Write-Log -Level "WARNING" -Message $message
                    Write-Warning $message 
                }
            }
        }
    }
    Write-Log -Level "INFO" -Message "Skanning klar."
} catch {
    Write-Log -Level "ERROR" -Message "Fel: $($.Exception.Message)"
    Write-Error "Fel vid skanning: $($.Exception.Message)"
    exit 1
}