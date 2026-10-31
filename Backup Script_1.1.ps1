#--------------------------------------------------------------
# Backup Script | Downloads all are tools for comp
# Branched from All in one | Script for start of comp | Version | 1.26.5
# Made by Logan Schultz
#Version | 1.1
#--------------------------------------------------------------
$ProgressPreference = 'SilentlyContinue'
function back-ups {
 #Global varabiles
 #Timestamp
 $ts = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    function backup-basesetup {
        Write-Host "========================================"
        Write-Host "|          System Backups              |"
        Write-Host "========================================"
        New-Item -ItemType Directory -Path "C:\Backups" -Force

        #Timestamp
        $ts = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $backupfiles = "C:\Backups"
        # Create backup Folder
        if (!(Test-Path $backupfiles)) {
            New-Item -ItemType Directory -Path $backupfiles | Out-Null
        }
    }
    function backup-local-dns {
        #DNS
        #--------------------------------------------------------------

        Write-Host "Starting DNS Backup" -ForegroundColor Green

        New-Item -ItemType Directory -Path "C:\Backups\DNS" -Force
        $backupPath = "C:\Backups\DNS\DNS_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
        New-Item -ItemType Directory -Path $backupPath -Force
        Copy-Item "C:\Windows\System32\dns\*" $backupPath -Recurse -Force

        Write-Host "DNS Backup complete" -ForegroundColor Green
    }
    function backup-local-Security-Policy {
        #Security Policys
        #--------------------------------------------------------------
        Write-Host "Starting Security Policy's Backup" -ForegroundColor Green

        New-Item -ItemType Directory -Path "C:\Backups\LocalSecurity" -Force
        $path = "C:\Backups\LocalSecurity\LocalSecurityPolicy_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').inf"
        secedit /export /cfg $path

        Write-Host "Security Policy's Backup complete" -ForegroundColor Green
    }
    function backup-local-firewall {
        #Firewall
        #--------------------------------------------------------------

        Write-Host "Starting Firewall Backup" -ForegroundColor Green

        New-Item -ItemType Directory -Path "C:\Backups\Firewall" -Force
        $path = "C:\Backups\Firewall\Firewall_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').wfw"
        netsh advfirewall export $path

        Write-Host "Firewall Backup complete" -ForegroundColor Green
    }
    function backup-local-Audit-Policy {
        #Audit Policy
        #--------------------------------------------------------------

        Write-Host "Starting Audit Policy Backup" -ForegroundColor Green

        New-Item -ItemType Directory -Path "C:\Backups\Audit" -Force
        #Backup-AuditPolicy -Path C:\Backups\Audit

        Write-Host "Audit Policy Backup complete" -ForegroundColor Green
    }
    function backup-Registry {
        #Registry
        #--------------------------------------------------------------

        Write-Host "Starting Registry Backup" -ForegroundColor Green

        New-Item -ItemType Directory -Path "C:\Backups\Registry" -Force
        New-Item -ItemType Directory -Path "C:\Backups\Registry\Registry_$ts" -Force

        reg export HKLM "C:\Backups\Registry\Registry_$ts\HKLM.reg" /y
        reg export HKCU "C:\Backups\Registry\Registry_$ts\HKCU.reg" /y
        reg export HKCR "C:\Backups\Registry\Registry_$ts\HKCR.reg" /y
        reg export HKU  "C:\Backups\Registry\Registry_$ts\HKU.reg"  /y
        reg export HKCC "C:\Backups\Registry\Registry_$ts\HKCC.reg" /y
        Write-Host "Registry Backup complete" -ForegroundColor Green
    }
    function backup-web-server {
        #Web Server Backups
        #--------------------------------------------------------------
        Write-Host "Starting Web Server Backup" -ForegroundColor Green
        New-Item -ItemType Directory -Path "C:\Backups\Web" -Force
        $backupPathWEB = "C:\Backups\Web\Web_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
        New-Item -ItemType Directory -Path $backupPathWEB -Force
        Copy-Item "C:\inetpub\*" $backupPathWEB -Recurse -Force
        Write-Host "Web Server Backup complete" -ForegroundColor Green
    }
    function backup-ftp-server {
        #FTP Server Backups
        #--------------------------------------------------------------

        Write-Host "Starting FTP Server Backup" -ForegroundColor Green

        New-Item -ItemType Directory -Path "C:\Backups\FTP-SITE" -Force
        $backupPathWEB = "C:\Backups\FTP\FTP_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss')"
        New-Item -ItemType Directory -Path $backupPathWEB -Force
        Copy-Item "C:\Backups\FTP-SITE\*" $backupPathWEB -Recurse -Force

    }
    function backup-dns-server {
        #DNS Server Backups
        #--------------------------------------------------------------
        function run-dnserverbackup{
        New-Item -ItemType Directory -Path $BackupDir -Force
                <#
        .SYNOPSIS
            Backs up DNS zones and records to JSON.

        .DESCRIPTION
            Exports all DNS zones and their resource records
            from a Windows DNS Server using the DnsServer module.
        #>

        param (
            #[string]$DnsServer = "localhost",
            [string]$BackupDir = "C:\Backup\DNS_Server\DNS-Backups"

        )

        # Ensure backup directory exists
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

        $timestamp  = Get-Date -Format "yyyy-MM-dd_HHmmss"
        $backupFile = Join-Path $BackupDir "DNSBackup_$timestamp.json"

        Write-Host "Starting DNS backup from $DnsServer" -ForegroundColor Cyan
        
        if (-not (Get-Module -ListAvailable -Name DnsServer)) {
            Write-Host "DnsServer module not found. Could not make backup." -ForegroundColor Red
        }

        Import-Module DnsServer

        $backup = @()

        $zones = Get-DnsServerZone -ComputerName $DnsServer

        foreach ($zone in $zones) {
            Write-Host "Backing up zone: $($zone.ZoneName)" -ForegroundColor Yellow

            $records = Get-DnsServerResourceRecord `
                -ComputerName $DnsServer `
                -ZoneName $zone.ZoneName

            $backup += [PSCustomObject]@{
                ZoneName = $zone.ZoneName
                ZoneType = $zone.ZoneType
                IsDsIntegrated = $zone.IsDsIntegrated
                Records = $records
            }
        }
        
        $backup | ConvertTo-Json -Depth 10 | Out-File -FilePath $backupFile -Encoding UTF8
        
        Write-Host "DNS backup completed:" -ForegroundColor Green
        Write-Host "  $backupFile" -ForegroundColor Gray
    }
}
    

Write-Host "========================================"
Write-Host "|          System backups              |"
Write-Host "========================================"

#Call all backups
backup-basesetup
backup-local-dns
backup-local-Security-Policy
backup-local-firewall
backup-local-Audit-Policy
backup-Registry
backup-web-server
backup-ftp-server
backup-dns-server

Write-Host "-----------------------------------------" -ForegroundColor Green
Write-Host "|          Backups complete             |" -ForegroundColor Green
Write-Host "-----------------------------------------" -ForegroundColor Green

} #Choice one
back-ups