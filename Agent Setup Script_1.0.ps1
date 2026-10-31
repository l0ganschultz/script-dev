#--------------------------------------------------------------
# Script agent setups
# Branched from All in one | Script for start of comp | Version | 1.26.5
# Made by Logan Schultz
#Version | 1.0
#--------------------------------------------------------------
$ProgressPreference = 'SilentlyContinue'

function agent-setup {
    function agentsetup-salt {
 <#
.SYNOPSIS
    Installs the Salt Minion on Windows using the official Broadcom MSI.

.DESCRIPTION
    Automates Salt Minion installation for Salt-GUI:
    - Verifies Administrator privileges
    - Supports interactive and non-interactive modes
    - Detects OS Architecture (64-bit vs 32-bit)
    - Downloads the correct MSI from the Broadcom repository
    - Performs a quiet install with logging
    - Configures Windows Firewall exceptions
    - Starts the service

.PARAMETER MasterIP
    The IP address or hostname of the Salt Master. Default: 172.20.242.20

.PARAMETER MinionID
    The unique identifier for this minion. Default: system hostname

.PARAMETER SaltVersion
    The Salt version to install. Default: 3007.13

.PARAMETER NonInteractive
    Run without prompts (requires MasterIP parameter)

.EXAMPLE
    # Interactive mode
    .\Install-SaltMinion.ps1

.EXAMPLE
    # Non-interactive mode
    .\Install-SaltMinion.ps1 -MasterIP "172.20.242.20" -MinionID "win-server01" -NonInteractive

.EXAMPLE
    # Specify custom Salt version
    .\Install-SaltMinion.ps1 -MasterIP "10.0.0.1" -SaltVersion "3007.13" -NonInteractive

.NOTES
    Based on original script by Samuel Brucker 2025-2026
    Modified for Salt-GUI integration
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$MasterIP = "",

    [Parameter(Mandatory=$false)]
    [string]$MinionID = "",

    [Parameter(Mandatory=$false)]
    [string]$SaltVersion = "3007.13",

    [Parameter(Mandatory=$false)]
    [switch]$NonInteractive
)

# --- Configuration ---
$DEFAULT_MASTER_IP = "172.20.242.20"
$ErrorActionPreference = "Stop"

# --- Functions ---
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $colors = @{
        "INFO" = "Green"
        "WARN" = "Yellow"
        "ERROR" = "Red"
        "DEBUG" = "Cyan"
    }
    $color = $colors[$Level]
    if (-not $color) { $color = "White" }
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-UserInput {
    param(
        [string]$Prompt,
        [string]$Default
    )

    if ($NonInteractive) {
        return $Default
    }

    $input = Read-Host -Prompt "$Prompt [Default: $Default]"
    if ([string]::IsNullOrWhiteSpace($input)) {
        return $Default
    }
    return $input
}

function Test-DomainController {
    $cs = Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue
    # DomainRole: 4 = Backup DC, 5 = Primary DC
    return ($null -ne $cs) -and ($cs.DomainRole -ge 4)
}

function Test-SaltMinionInstalled {
    $service = Get-Service -Name "salt-minion" -ErrorAction SilentlyContinue
    return $null -ne $service
}

function Uninstall-ExistingMinion {
    Write-Log "Removing existing Salt Minion to ensure clean install..." "WARN"

    # Stop the service first
    $service = Get-Service -Name "salt-minion" -ErrorAction SilentlyContinue
    if ($service -and $service.Status -ne 'Stopped') {
        Stop-Service -Name "salt-minion" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
    }

    # Find and uninstall via MSI product code
    $product = Get-WmiObject Win32_Product | Where-Object { $_.Name -like '*Salt Minion*' }
    if ($product) {
        Write-Log "Uninstalling: $($product.Name) $($product.Version)"
        $result = $product.Uninstall()
        if ($result.ReturnValue -eq 0) {
            Write-Log "Previous version uninstalled successfully"
        } else {
            Write-Log "Uninstall returned code: $($result.ReturnValue)" "WARN"
        }
        Start-Sleep -Seconds 3
    } else {
        # Fallback: just stop the service if WMI can't find the product
        Write-Log "Could not find MSI product entry, stopping service only" "WARN"
    }
}

function Stop-ExistingMinion {
    $service = Get-Service -Name "salt-minion" -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq 'Running') {
        Write-Log "Stopping existing Salt Minion service..." "WARN"
        Stop-Service -Name "salt-minion" -Force
        Start-Sleep -Seconds 2
    }
}

function Test-PreFlightChecks {
    param(
        [string]$MasterIP
    )

    Write-Log "Running pre-flight checks..."
    $failed = $false

    # 1. PowerShell Execution Policy - check if GPO blocks script execution
    $machinePolicy = Get-ExecutionPolicy -Scope MachinePolicy
    $userPolicy = Get-ExecutionPolicy -Scope UserPolicy
    if ($machinePolicy -ne 'Undefined' -and $machinePolicy -ne 'Bypass' -and $machinePolicy -ne 'Unrestricted') {
        Write-Log "GPO enforces execution policy: $machinePolicy (MachinePolicy scope)" "ERROR"
        Write-Log "  Fix: Ask domain admin to allow scripts, or run:" "WARN"
        Write-Log "  powershell.exe -ExecutionPolicy Bypass -File $($MyInvocation.ScriptName)" "WARN"
        $failed = $true
    } elseif ($userPolicy -ne 'Undefined' -and $userPolicy -ne 'Bypass' -and $userPolicy -ne 'Unrestricted') {
        Write-Log "GPO enforces execution policy: $userPolicy (UserPolicy scope)" "WARN"
    }

    # 2. PowerShell Language Mode - Constrained Language blocks .NET calls
    if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
        Write-Log "PowerShell is in $($ExecutionContext.SessionState.LanguageMode) mode" "ERROR"
        Write-Log "  This is typically caused by Device Guard/WDAC policy" "WARN"
        Write-Log "  Salt Minion installation requires FullLanguage mode" "WARN"
        $failed = $true
    }

    # 3. MSI installer restrictions via GPO
    $msiPolicy = Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer' -ErrorAction SilentlyContinue
    if ($msiPolicy) {
        # DisableMSI: 0=never, 1=non-managed only, 2=always
        if ($msiPolicy.DisableMSI -eq 2) {
            Write-Log "GPO blocks all MSI installations (DisableMSI=2)" "ERROR"
            Write-Log "  Fix: Domain admin must set 'Disable Windows Installer' to 'Never'" "WARN"
            $failed = $true
        } elseif ($msiPolicy.DisableMSI -eq 1) {
            Write-Log "GPO restricts non-managed MSI installations" "WARN"
            Write-Log "  Installation may still work for administrators" "WARN"
        }
    }

    # 4. Windows Defender - check if it could quarantine Salt
    $defender = Get-MpPreference -ErrorAction SilentlyContinue
    if ($defender -and -not $defender.DisableRealtimeMonitoring) {
        $saltPath = "C:\Program Files\Salt Project\Salt"
        $excluded = $false
        if ($defender.ExclusionPath) {
            foreach ($exc in $defender.ExclusionPath) {
                if ($saltPath.StartsWith($exc.TrimEnd('\')) -or $exc.TrimEnd('\').StartsWith($saltPath)) {
                    $excluded = $true
                    break
                }
            }
        }
        if (-not $excluded) {
            Write-Log "Windows Defender real-time protection is active" "WARN"
            Write-Log "  Salt may be flagged as a remote admin tool. Adding exclusion..." "WARN"
            try {
                $existing = @()
                if ($defender.ExclusionPath) { $existing = @($defender.ExclusionPath) }
                $newExclusions = $existing + @($saltPath, "C:\ProgramData\Salt Project\Salt") | Select-Object -Unique
                Set-MpPreference -ExclusionPath $newExclusions -ErrorAction Stop
                Write-Log "  Defender exclusions added for Salt directories"
            } catch {
                Write-Log "  Could not add Defender exclusion (may need manual GPO change)" "WARN"
                Write-Log "  If install fails, manually exclude: $saltPath" "WARN"
            }
        }
    }

    # 5. Network proxy detection
    $proxyEnabled = $false
    $winHttpProxy = netsh winhttp show proxy 2>&1 | Out-String
    if ($winHttpProxy -match 'Proxy Server\(s\)\s*:\s*\S') {
        Write-Log "System proxy detected (WinHTTP): check netsh winhttp show proxy" "WARN"
        Write-Log "  Download may fail if proxy requires authentication" "WARN"
        $proxyEnabled = $true
    }
    $ieProxy = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
    if ($ieProxy -and $ieProxy.ProxyEnable -eq 1) {
        Write-Log "IE/User proxy enabled: $($ieProxy.ProxyServer)" "WARN"
        $proxyEnabled = $true
    }

    # 6. Network connectivity to Salt Master
    $portTest = Test-NetConnection -ComputerName $MasterIP -Port 4506 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    if (-not $portTest.TcpTestSucceeded) {
        Write-Log "Cannot reach Salt Master at ${MasterIP}:4506" "ERROR"
        Write-Log "  Check firewall rules and network connectivity" "WARN"
        # Also test 4505
        $pubTest = Test-NetConnection -ComputerName $MasterIP -Port 4505 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        if (-not $pubTest.TcpTestSucceeded) {
            Write-Log "  Also cannot reach ${MasterIP}:4505" "ERROR"
        }
        $failed = $true
    } else {
        Write-Log "Salt Master reachable at ${MasterIP}:4506"
    }

    # 7. Firewall GPO override check - local rules may be ignored
    $domainProfile = Get-NetFirewallProfile -Name Domain -ErrorAction SilentlyContinue
    if ($domainProfile -and $domainProfile.Enabled) {
        $gpoRules = Get-NetFirewallRule -PolicyStore ActiveStore -ErrorAction SilentlyContinue |
            Where-Object { $_.PolicyStoreSource -eq 'GroupPolicy' } |
            Measure-Object
        if ($gpoRules.Count -gt 0) {
            Write-Log "GPO firewall rules detected ($($gpoRules.Count) rules)" "WARN"
            Write-Log "  Local firewall rules may be overridden by domain policy" "WARN"
            Write-Log "  Ensure Salt ports 4505/4506 outbound are allowed in GPO" "WARN"
        }
    }

    # 8. AppLocker check
    try {
        $appLocker = Get-AppLockerPolicy -Effective -ErrorAction Stop
        $msiRules = $appLocker.RuleCollections | Where-Object { $_.RuleCollectionType -eq 'Msi' }
        $exeRules = $appLocker.RuleCollections | Where-Object { $_.RuleCollectionType -eq 'Exe' }
        if ($msiRules -and $msiRules.Count -gt 0) {
            Write-Log "AppLocker MSI rules are active ($($msiRules.Count) rules)" "WARN"
            Write-Log "  MSI installation may be blocked if not whitelisted" "WARN"
        }
        if ($exeRules -and $exeRules.Count -gt 0) {
            Write-Log "AppLocker EXE rules are active ($($exeRules.Count) rules)" "WARN"
            Write-Log "  salt-minion.exe may be blocked after installation" "WARN"
        }
    } catch {
        # AppLocker not configured - this is fine
    }

    if ($failed) {
        Write-Log "Pre-flight checks found blocking issues (see above)" "ERROR"
        return $false
    }

    Write-Log "Pre-flight checks passed"
    return $true
}

function Get-SaltInstallerUrl {
    param(
        [string]$Version
    )

    if ([Environment]::Is64BitOperatingSystem) {
        Write-Log "Detected 64-bit Operating System"
        $arch = "AMD64"
    } else {
        Write-Log "Detected 32-bit Operating System"
        $arch = "x86"
    }

    $fileName = "Salt-Minion-$Version-Py3-$arch.msi"
    $url = "https://packages.broadcom.com/artifactory/saltproject-generic/windows/$Version/$fileName"

    return @{
        Url = $url
        FileName = $fileName
        Arch = $arch
    }
}

function Install-SaltMinion {
    param(
        [string]$InstallerPath,
        [string]$MasterIP,
        [string]$MinionID,
        [string]$LogPath
    )

    Write-Log "Installing Salt Minion..."
    Write-Log "  Master: $MasterIP"
    Write-Log "  Minion ID: $MinionID"

    $msiArgs = @(
        "/i", "`"$InstallerPath`"",
        "/quiet",
        "/norestart",
        "/log", "`"$LogPath`"",
        "MASTER=$MasterIP",
        "MINION_ID=$MinionID",
        "START_MINION=1"
    )

    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru

    if ($process.ExitCode -ne 0) {
        Write-Log "Installer exited with code: $($process.ExitCode)" "ERROR"
        Write-Log "Check log file: $LogPath" "WARN"
        throw "Installation failed with exit code $($process.ExitCode)"
    }

    Write-Log "Installation completed successfully"
}

function Set-FirewallRules {
    Write-Log "Configuring Windows Firewall..."

    # Common Salt Minion paths (3007+ installs to root, older to bin/)
    $saltPaths = @(
        "C:\Program Files\Salt Project\Salt\salt-minion.exe",
        "C:\Program Files\Salt Project\Salt\bin\salt-minion.exe",
        "C:\salt\salt-minion.exe",
        "C:\salt\bin\salt-minion.exe"
    )

    $saltExe = $null
    foreach ($path in $saltPaths) {
        if (Test-Path $path) {
            $saltExe = $path
            break
        }
    }

    if ($saltExe) {
        # Remove existing rules if any
        Get-NetFirewallRule -DisplayName "Salt Minion*" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue

        # Add inbound rule for salt-minion
        New-NetFirewallRule -DisplayName "Salt Minion" `
            -Direction Inbound `
            -Program $saltExe `
            -Action Allow `
            -Profile Any `
            -Description "Allow Salt Minion communication" `
            -ErrorAction SilentlyContinue | Out-Null

        Write-Log "Firewall rules configured for: $saltExe"
    } else {
        Write-Log "Could not find salt-minion.exe - skipping firewall configuration" "WARN"
    }
}

function Start-SaltMinionService {
    Write-Log "Configuring Salt Minion service..."

    $serviceName = "salt-minion"
    $maxAttempts = 5
    $attempt = 0

    # Wait for service to be registered
    while ($attempt -lt $maxAttempts) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            break
        }
        $attempt++
        Write-Log "Waiting for service registration... (attempt $attempt/$maxAttempts)" "DEBUG"
        Start-Sleep -Seconds 2
    }

    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if (-not $service) {
        Write-Log "Service '$serviceName' not found after installation" "ERROR"
        return $false
    }

    # On Domain Controllers, use delayed auto-start so salt-minion waits for
    # AD DS (NTDS) to fully initialize after reboot. Without this, Salt's
    # win32net.NetUserGetLocalGroups() call can fail with error 1355 if AD
    # services haven't started yet.
    if ($isDC) {
        Write-Log "Setting delayed auto-start for DC compatibility"
        sc.exe config $serviceName start= delayed-auto | Out-Null
    } else {
        Set-Service -Name $serviceName -StartupType Automatic
    }

    # Start if not running
    if ($service.Status -ne 'Running') {
        Start-Service -Name $serviceName
        Start-Sleep -Seconds 3
    }

    # Check for "Paused" state - a known issue where Salt's SSM service
    # manager fails to fully start (common with VC++ runtime issues or
    # on DCs where AD queries fail during startup)
    $service = Get-Service -Name $serviceName
    if ($service.Status -eq 'Paused') {
        Write-Log "Service entered 'Paused' state, attempting recovery..." "WARN"
        Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5
        Start-Service -Name $serviceName
        Start-Sleep -Seconds 5
        $service = Get-Service -Name $serviceName
    }

    # Verify running
    if ($service.Status -eq 'Running') {
        Write-Log "Service '$serviceName' is running"
        return $true
    } else {
        Write-Log "Service '$serviceName' status: $($service.Status)" "WARN"
        if ($isDC -and $service.Status -ne 'Running') {
            Write-Log "On DCs, the service may need AD to fully start. Try: Restart-Service salt-minion" "WARN"
        }
        return $false
    }
}

# --- Main Script ---

# Banner
Write-Host ""
Write-Host "#####################################################" -ForegroundColor Green
Write-Host "# Salt Minion Installer for Salt-GUI (Windows)      #" -ForegroundColor Green
Write-Host "# Salt Version: $SaltVersion                              #" -ForegroundColor Green
Write-Host "#####################################################" -ForegroundColor Green
Write-Host ""

# Administrator check
if (-not (Test-Administrator)) {
    Write-Log "This script must be run with Administrator privileges" "ERROR"
    Write-Log "Please right-click and select 'Run as Administrator'" "WARN"
    if (-not $NonInteractive) {
        Read-Host "Press Enter to exit..."
    }
    exit 1
}

# Get Master IP
if ([string]::IsNullOrWhiteSpace($MasterIP)) {
    $MasterIP = Get-UserInput -Prompt "Enter Salt Master IP" -Default $DEFAULT_MASTER_IP
}
Write-Log "Master IP: $MasterIP"

# Get Minion ID
if ([string]::IsNullOrWhiteSpace($MinionID)) {
    $defaultID = $env:COMPUTERNAME
    $MinionID = Get-UserInput -Prompt "Enter Minion ID" -Default $defaultID
}
Write-Log "Minion ID: $MinionID"

# Detect Domain Controller
$isDC = Test-DomainController
if ($isDC) {
    $dcDomain = (Get-WmiObject Win32_ComputerSystem).Domain
    Write-Log "Domain Controller detected (domain: $dcDomain)" "WARN"
    Write-Log "DC-specific mitigations will be applied" "WARN"
}

# Warn on hostname vs minion ID mismatch
if ($MinionID -ne $env:COMPUTERNAME -and $MinionID -ne $env:COMPUTERNAME.ToLower()) {
    Write-Log "Minion ID '$MinionID' differs from hostname '$($env:COMPUTERNAME)'" "WARN"
    $fqdn = [System.Net.Dns]::GetHostEntry($env:COMPUTERNAME).HostName
    if ($MinionID -ne $fqdn -and $MinionID -ne $fqdn.ToLower()) {
        Write-Log "Minion ID also differs from FQDN '$fqdn'" "WARN"
    }
}

# Pre-flight checks for common AD/GPO blockers
$preFlightOk = Test-PreFlightChecks -MasterIP $MasterIP
if (-not $preFlightOk) {
    if (-not $NonInteractive) {
        $continue = Read-Host "Continue anyway? (y/N)"
        if ($continue -ne 'y' -and $continue -ne 'Y') {
            Write-Log "Installation aborted by user"
            exit 1
        }
    } else {
        Write-Log "Pre-flight failures in non-interactive mode, aborting" "ERROR"
        exit 1
    }
}

# Check for existing installation
if (Test-SaltMinionInstalled) {
    Write-Log "Existing Salt Minion installation detected" "WARN"
    Uninstall-ExistingMinion
}

# Get installer URL
$installer = Get-SaltInstallerUrl -Version $SaltVersion
$downloadPath = Join-Path $env:TEMP $installer.FileName
$logPath = Join-Path $env:TEMP "salt_install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

try {
    # Download installer
    Write-Log "Downloading Salt Minion installer..."
    Write-Log "  URL: $($installer.Url)" "DEBUG"
    Write-Log "  Destination: $downloadPath" "DEBUG"

    # Configure TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Download with retry
    $maxRetries = 3
    $retryCount = 0
    $downloaded = $false

    while (-not $downloaded -and $retryCount -lt $maxRetries) {
        try {
            $retryCount++
            Write-Log "Download attempt $retryCount/$maxRetries..."
            Invoke-WebRequest -Uri $installer.Url -OutFile $downloadPath -UseBasicParsing
            $downloaded = $true
        } catch {
            if ($retryCount -lt $maxRetries) {
                Write-Log "Download failed, retrying in 5 seconds..." "WARN"
                Start-Sleep -Seconds 5
            } else {
                throw
            }
        }
    }

    # Verify download
    if (-not (Test-Path $downloadPath)) {
        throw "Installer file not found after download"
    }

    $fileSize = (Get-Item $downloadPath).Length / 1MB
    Write-Log "Downloaded: $([math]::Round($fileSize, 2)) MB"

    # Install
    Install-SaltMinion -InstallerPath $downloadPath -MasterIP $MasterIP -MinionID $MinionID -LogPath $logPath

    # Configure firewall
    Set-FirewallRules

    # Start service
    $serviceStarted = Start-SaltMinionService

    # Summary
    Write-Host ""
    Write-Host "#####################################################" -ForegroundColor Green
    Write-Host "# MINION SETUP COMPLETE                             #" -ForegroundColor Green
    Write-Host "#####################################################" -ForegroundColor Green
    Write-Host ""
    Write-Host "Minion ID:  $MinionID"
    Write-Host "Master IP:  $MasterIP"
    Write-Host "Status:     $(if ($serviceStarted) { 'Running' } else { 'Check Required' })"
    if ($isDC) {
        Write-Host "DC Mode:    Yes (delayed auto-start enabled)"
    }
    Write-Host "Log File:   $logPath"
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Accept the key on the master:"
    Write-Host "     salt-key -a '$MinionID'"
    Write-Host "  2. Test connectivity:"
    Write-Host "     salt '$MinionID' test.ping"
    Write-Host ""

} catch {
    Write-Log "An error occurred: $_" "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" "DEBUG"
    if (-not $NonInteractive) {
        Read-Host "Press Enter to exit..."
    }
    exit 1
} finally {
    # Cleanup downloaded installer
    if (Test-Path $downloadPath) {
        Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue
    }
}

if (-not $NonInteractive) {
    Read-Host "Press Enter to exit..."
}
} #salt
    function agentsetup-wazuh {
    #Requires -RunAsAdministrator
<#
.SYNOPSIS
    Universal Wazuh Agent Installation Script for Windows

.DESCRIPTION
    This script automatically downloads, installs, and configures the Wazuh agent
    on Windows systems, then registers it with a predefined Wazuh manager.

    Manager IP is configurable via parameter or environment variable.

    Created by Samuel Brucker, 2025-2026

.PARAMETER ManagerIP
    The IP address of the Wazuh manager. Defaults to 172.20.242.20

.PARAMETER AgentGroup
    The agent group to assign. Defaults to windows-default

.PARAMETER AgentName
    Custom agent name. Defaults to the computer hostname

.PARAMETER SkipServiceStart
    If specified, installs but doesn't start the service

.EXAMPLE
    .\WazuhWindowsAgentSetup.ps1

.EXAMPLE
    .\WazuhWindowsAgentSetup.ps1 -ManagerIP "192.168.1.100" -AgentGroup "windows-servers"

.EXAMPLE
    .\WazuhWindowsAgentSetup.ps1 -AgentName "DC01-Production"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ManagerIP = $env:WAZUH_MANAGER_IP,

    [Parameter(Mandatory=$false)]
    [string]$AgentGroup = $env:WAZUH_AGENT_GROUP,

    [Parameter(Mandatory=$false)]
    [string]$AgentName = $env:COMPUTERNAME,

    [Parameter(Mandatory=$false)]
    [switch]$SkipServiceStart
)

# ============================================================================
# Configuration
# ============================================================================
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Default values if not provided
if ([string]::IsNullOrEmpty($ManagerIP)) {
    $ManagerIP = "172.20.242.20"
}
if ([string]::IsNullOrEmpty($AgentGroup)) {
    $AgentGroup = "windows-default"
}

# Wazuh version and download URL
$WazuhVersion = "4.14.2-1"
$WazuhMsiUrl = "https://packages.wazuh.com/4.x/windows/wazuh-agent-$WazuhVersion.msi"
$WazuhMsiPath = "$env:TEMP\wazuh-agent.msi"

# Paths
$WazuhInstallDir = "C:\Program Files (x86)\ossec-agent"
$LogFile = "$env:TEMP\wazuh_agent_installer.log"

# ============================================================================
# Utility Functions
# ============================================================================

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$Level] $timestamp - $Message"

    # Write to console with color
    switch ($Level) {
        "INFO"  { Write-Host $logMessage -ForegroundColor Green }
        "WARN"  { Write-Host $logMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
    }

    # Append to log file
    Add-Content -Path $LogFile -Value $logMessage
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-WazuhInstalled {
    return (Test-Path "$WazuhInstallDir\wazuh-agent.exe")
}

function Get-WazuhService {
    return Get-Service -Name "WazuhSvc" -ErrorAction SilentlyContinue
}

# ============================================================================
# Installation Functions
# ============================================================================

function Remove-ExistingWazuh {
    Write-Log "Checking for existing Wazuh installation..."

    $service = Get-WazuhService
    if ($service) {
        Write-Log "Stopping existing Wazuh service..." -Level "WARN"
        Stop-Service -Name "WazuhSvc" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }

    if (Test-WazuhInstalled) {
        Write-Log "Removing existing Wazuh installation..." -Level "WARN"

        # Try to uninstall via MSI
        $uninstallKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*Wazuh*" }

        if ($uninstallKey) {
            $uninstallString = $uninstallKey.UninstallString
            if ($uninstallString -match "msiexec") {
                $productCode = $uninstallKey.PSChildName
                Write-Log "Uninstalling Wazuh via MSI (Product: $productCode)..."
                Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $productCode /qn /norestart" -Wait -NoNewWindow
                Start-Sleep -Seconds 5
            }
        }

        # Clean up remaining files if any
        if (Test-Path $WazuhInstallDir) {
            Write-Log "Cleaning up remaining files..."
            Remove-Item -Path $WazuhInstallDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Log "Cleanup complete."
}

function Get-WazuhInstaller {
    Write-Log "Downloading Wazuh agent MSI from $WazuhMsiUrl..."

    # Remove existing download if present
    if (Test-Path $WazuhMsiPath) {
        Remove-Item -Path $WazuhMsiPath -Force
    }

    try {
        # Enable TLS 1.2 (and TLS 1.3 if available - not present on Server 2016/2019)
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls13 -bor [Net.SecurityProtocolType]::Tls12
        } catch {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        }

        # Download using Invoke-WebRequest (WebClient is deprecated)
        Write-Log "Downloading (this may take a moment)..."
        Invoke-WebRequest -Uri $WazuhMsiUrl -OutFile $WazuhMsiPath -UseBasicParsing -ErrorAction Stop

        if (-not (Test-Path $WazuhMsiPath)) {
            throw "Download failed - file not found"
        }

        $fileSize = (Get-Item $WazuhMsiPath).Length / 1MB
        Write-Log "Download complete. File size: $([math]::Round($fileSize, 2)) MB"
    }
    catch {
        Write-Log "Failed to download Wazuh agent: $_" -Level "ERROR"
        throw
    }
}
    function Install-WazuhAgent {
    Write-Log "Installing Wazuh agent..."
    Write-Log "  Manager IP: $ManagerIP"
    Write-Log "  Agent Group: $AgentGroup"
    Write-Log "  Agent Name: $AgentName"

    # Build MSI arguments
    $msiArgs = @(
        "/i", $WazuhMsiPath,
        "/qn",
        "/norestart",
        "WAZUH_MANAGER=$ManagerIP",
        "WAZUH_AGENT_GROUP=$AgentGroup",
        "WAZUH_AGENT_NAME=$AgentName",
        "/l*v", "$env:TEMP\wazuh_msi_install.log"
    )

    Write-Log "Running MSI installer..."
    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -ne 0) {
        Write-Log "MSI installation failed with exit code: $($process.ExitCode)" -Level "ERROR"
        Write-Log "Check $env:TEMP\wazuh_msi_install.log for details" -Level "ERROR"
        throw "Installation failed"
    }

    # Verify installation
    Start-Sleep -Seconds 3
    if (-not (Test-WazuhInstalled)) {
        Write-Log "Installation verification failed - agent not found" -Level "ERROR"
        throw "Installation verification failed"
    }

    Write-Log "Wazuh agent installed successfully."
}

function Set-WazuhConfiguration {
    Write-Log "Verifying agent configuration..."

    $configFile = "$WazuhInstallDir\ossec.conf"

    if (-not (Test-Path $configFile)) {
        Write-Log "Configuration file not found at $configFile" -Level "ERROR"
        throw "Configuration file missing"
    }

    # Read and verify manager IP is set using XML parsing
    try {
        [xml]$config = Get-Content $configFile
        $currentAddress = $config.ossec_config.client.server.address
        if ($currentAddress -eq $ManagerIP) {
            Write-Log "Manager IP correctly configured: $ManagerIP"
        }
        else {
            Write-Log "Manager IP is '$currentAddress', updating to '$ManagerIP'..." -Level "WARN"

            # Backup original config
            $backupPath = "$configFile.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
            Copy-Item -Path $configFile -Destination $backupPath
            Write-Log "Configuration backed up to $backupPath"

            # Update via XML DOM
            $config.ossec_config.client.server.address = $ManagerIP
            $config.Save($configFile)
            Write-Log "Configuration updated with manager IP: $ManagerIP"
        }
    }
    catch {
        Write-Log "XML parsing failed, falling back to regex replacement..." -Level "WARN"
        $configContent = Get-Content $configFile -Raw
        $backupPath = "$configFile.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item -Path $configFile -Destination $backupPath
        $configContent = $configContent -replace '<address>[^<]+</address>', "<address>$ManagerIP</address>"
        Set-Content -Path $configFile -Value $configContent -Encoding UTF8
        Write-Log "Configuration updated with manager IP: $ManagerIP (regex fallback)"
    }
}

function Start-WazuhService {
    Write-Log "Starting Wazuh agent service..."

    $service = Get-WazuhService
    if (-not $service) {
        Write-Log "Wazuh service not found. Attempting to register..." -Level "WARN"

        # Try to install the service
        $installService = "$WazuhInstallDir\wazuh-agent.exe"
        if (Test-Path $installService) {
            Start-Process -FilePath $installService -ArgumentList "install-service" -Wait -NoNewWindow
            Start-Sleep -Seconds 2
            $service = Get-WazuhService
        }
    }

    if (-not $service) {
        Write-Log "Failed to find or create Wazuh service" -Level "ERROR"
        throw "Service creation failed"
    }

    # Start the service
    Start-Service -Name "WazuhSvc"
    Start-Sleep -Seconds 5

    # Verify service is running
    $service = Get-WazuhService
    if ($service.Status -eq "Running") {
        Write-Log "Wazuh agent service is running."
    }
    else {
        Write-Log "Service status: $($service.Status)" -Level "WARN"
        Write-Log "Service may need time to connect to manager. Check status later." -Level "WARN"
    }
}

function Show-AgentStatus {
    Write-Log "============================================================"
    Write-Log "Agent Status Information"
    Write-Log "============================================================"

    # Get service status
    $service = Get-WazuhService
    if ($service) {
        Write-Log "Service Status: $($service.Status)"
    }

    # Try to get agent info
    $agentControl = "$WazuhInstallDir\agent-control.exe"
    if (Test-Path $agentControl) {
        try {
            $agentInfo = & $agentControl -i 2>&1
            Write-Log "Agent Info:"
            $agentInfo | ForEach-Object { Write-Log "  $_" }
        }
        catch {
            Write-Log "Could not retrieve agent info" -Level "WARN"
        }
    }
    else {
        Write-Log "agent-control.exe not found at $agentControl" -Level "WARN"
    }
}

function Add-FirewallRules {
    Write-Log "Configuring Windows Firewall rules for Wazuh..."

    # Remove only our specific rules (not all Wazuh* rules)
    Get-NetFirewallRule -DisplayName "Wazuh Agent - Outbound" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
    Get-NetFirewallRule -DisplayName "Wazuh Agent Enrollment - Outbound" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue

    # Add outbound rule for agent communication (port 1514)
    New-NetFirewallRule -DisplayName "Wazuh Agent - Outbound" `
        -Direction Outbound `
        -Protocol TCP `
        -LocalPort Any `
        -RemotePort 1514 `
        -Action Allow `
        -Profile Any `
        -Description "Allow Wazuh agent to communicate with manager" `
        -ErrorAction SilentlyContinue | Out-Null

    # Add outbound rule for enrollment (port 1515)
    New-NetFirewallRule -DisplayName "Wazuh Agent Enrollment - Outbound" `
        -Direction Outbound `
        -Protocol TCP `
        -LocalPort Any `
        -RemotePort 1515 `
        -Action Allow `
        -Profile Any `
        -Description "Allow Wazuh agent enrollment" `
        -ErrorAction SilentlyContinue | Out-Null

    Write-Log "Firewall rules configured."
}

# ============================================================================
# Main Execution
# ============================================================================

function Main {
    # Initialize log file
    if (Test-Path $LogFile) {
        Remove-Item -Path $LogFile -Force
    }

    Write-Log "============================================================"
    Write-Log "Wazuh Agent Windows Installer"
    Write-Log "============================================================"
    Write-Log "Computer Name: $env:COMPUTERNAME"
    Write-Log "Windows Version: $([Environment]::OSVersion.VersionString)"
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)"
    Write-Log "============================================================"

    # Verify administrator privileges
    if (-not (Test-Administrator)) {
        Write-Log "This script must be run as Administrator." -Level "ERROR"
        exit 1
    }

    try {
        # Step 1: Remove existing installation
        Remove-ExistingWazuh

        # Step 2: Download installer
        Get-WazuhInstaller

        # Step 3: Install agent
        Install-WazuhAgent

        # Step 4: Configure agent
        Set-WazuhConfiguration

        # Step 5: Configure firewall
        Add-FirewallRules

        # Step 6: Start service (unless skipped)
        if (-not $SkipServiceStart) {
            Start-WazuhService
        }
        else {
            Write-Log "Service start skipped per user request." -Level "WARN"
        }

        # Step 7: Show status
        Show-AgentStatus

        # Cleanup
        if (Test-Path $WazuhMsiPath) {
            Remove-Item -Path $WazuhMsiPath -Force -ErrorAction SilentlyContinue
        }

        Write-Log "============================================================"
        Write-Log "Wazuh Agent Installation Complete!"
        Write-Log "The agent is configured to report to manager: $ManagerIP"
        Write-Log "Agent Group: $AgentGroup"
        Write-Log "Log file: $LogFile"
        Write-Log "============================================================"
    }
    catch {
        Write-Log "Installation failed: $_" -Level "ERROR"
        Write-Log "Check log file for details: $LogFile" -Level "ERROR"
        exit 1
    }
}

# Run main function
Main
    
} #wazuh
    function agentsetup-splunk{
param (
    # Optional: Specify the IP address of the Splunk Indexer (receiver).
    [string]$INDEXER_IP = "172.20.242.20",

    # Optional: Specify the hostname to be used by Splunk.
    # Defaults to the machine's current hostname.
    [string]$SplunkHostname = $env:COMPUTERNAME,

    # Optional: Specify the admin password for the Splunk forwarder.
    # Required for Splunk 7.1+ silent installs.
    [string]$SplunkPassword = "changeme"
)

# PowerShell script to install and configure Splunk Universal Forwarder on Windows machines
# This was originally written in Bash, then translated to Powershell. An AI was (obviously) used heavily in this process. I only know a small, salty lick of
# PowerShell, this is 70% AI, 25% forums, and 5% me pushing buttons until it worked.
#
# You can be mean to this one. I know it's rough.
#
#  Currently set to v10.0.1. I'm not sure if the link will be valid during the entire competition season
# with how much is still left to go. If the download gives you any trouble, create a Splunk account, go to the universal forwarder downloads, pick the one you want,
# then extract the random set of characters found in the link. In this script, these are stored in the variable "SPLUNK_BUILD".
#
# Samuel Brucker 2024 - 2026

$ErrorActionPreference = "Stop"

# Define variables
$SPLUNK_VERSION = "10.0.2"
$SPLUNK_BUILD = "e2d18b4767e9"
$SPLUNK_MSI_NAME = "splunkforwarder-${SPLUNK_VERSION}-${SPLUNK_BUILD}-windows-x64.msi"
$SPLUNK_DOWNLOAD_URL = "https://download.splunk.com/products/universalforwarder/releases/${SPLUNK_VERSION}/windows/${SPLUNK_MSI_NAME}"
$SPLUNK_MSI_PATH = Join-Path $env:TEMP $SPLUNK_MSI_NAME
$INSTALL_DIR = "C:\Program Files\SplunkUniversalForwarder"
# $INDEXER_IP is now defined in the param() block at the top
$RECEIVER_PORT = "9997"

# Check for existing installation
if (Test-Path "$INSTALL_DIR\bin\splunk.exe") {
    Write-Host "[OK] Existing Splunk Universal Forwarder found at $INSTALL_DIR - skipping install, updating configuration" -ForegroundColor Cyan
    # Ensure service runs as LocalSystem (needed to read Sysmon, SMBServer, and other protected event logs)
    $svcAccount = (Get-WmiObject Win32_Service -Filter "Name='SplunkForwarder'").StartName
    if ($svcAccount -ne "LocalSystem") {
        Write-Host "Changing SplunkForwarder service account from '$svcAccount' to LocalSystem..."
        sc.exe config SplunkForwarder obj= LocalSystem | Out-Null
    }
} else {
    # Download Splunk Universal Forwarder MSI
    Write-Host "Downloading Splunk Universal Forwarder MSI..."
    # Ensure TLS 1.2 is available (older PowerShell defaults to TLS 1.0 which download.splunk.com rejects)
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    #take away the progress bar, but drastically speeds up downloads on older powershell versions
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri $SPLUNK_DOWNLOAD_URL -OutFile $SPLUNK_MSI_PATH
    } catch {
        Write-Host "[ERROR] Failed to download Splunk UF: $_" -ForegroundColor Red
        exit 1
    }

    if (-not (Test-Path $SPLUNK_MSI_PATH)) {
        Write-Host "[ERROR] MSI not found at $SPLUNK_MSI_PATH after download" -ForegroundColor Red
        exit 1
    }

    # Install Splunk Universal Forwarder
    Write-Host "Installing Splunk Universal Forwarder..."
    # The $INDEXER_IP variable will be pulled from the parameters
    $msiArgs = "/i `"$SPLUNK_MSI_PATH`" AGREETOLICENSE=Yes SPLUNKPASSWORD=$SplunkPassword RECEIVING_INDEXER=${INDEXER_IP}:${RECEIVER_PORT} LOGON_USERNAME=LocalSystem /quiet"
    $install = Start-Process -FilePath "msiexec.exe" -ArgumentList $msiArgs -Wait -PassThru
    if ($install.ExitCode -ne 0) {
        Write-Host "[ERROR] MSI install failed with exit code $($install.ExitCode)" -ForegroundColor Red
        exit 1
    }

    # Verify install directory exists
    if (-not (Test-Path "$INSTALL_DIR\bin\splunk.exe")) {
        Write-Host "[ERROR] Splunk UF not found at $INSTALL_DIR after install" -ForegroundColor Red
        exit 1
    }

    Write-Host "[OK] Splunk Universal Forwarder installed" -ForegroundColor Green

    # Clean up downloaded MSI
    Remove-Item $SPLUNK_MSI_PATH -ErrorAction SilentlyContinue
}

# Configure inputs.conf for monitoring
$inputsConfPath = "$INSTALL_DIR\etc\system\local\inputs.conf"
Write-Host "Configuring inputs.conf for monitoring..."
@"
## -----------------------------------------------------------------------------
# Testing
# -----------------------------------------------------------------------------

[monitor://C:\temp\test.log]
disabled = 0
index = windows
sourcetype = test

# -----------------------------------------------------------------------------
# Standard Windows Event Logs
# -----------------------------------------------------------------------------

[WinEventLog://Application]
disabled = 0
index = windows

[WinEventLog://Security]
disabled = 0
index = windows

[WinEventLog://System]
disabled = 0
index = windows

# -----------------------------------------------------------------------------
# Security Services (Defender, Sysmon)
# -----------------------------------------------------------------------------

[WinEventLog://Microsoft-Windows-Windows Defender/Operational]
disabled = 0
index = windows
sourcetype = WinEventLog:Defender

[WinEventLog://Microsoft-Windows-Sysmon/Operational]
disabled = 0
index = windows
sourcetype = WinEventLog:Sysmon

# -----------------------------------------------------------------------------
# Additional Lateral Movement (WinRM, WMI, SMB, AtExec)
# -----------------------------------------------------------------------------

[WinEventLog://Microsoft-Windows-PowerShell/Operational]
disabled = 0
index = windows
sourcetype = WinEventLog:PowerShell

[WinEventLog://Microsoft-Windows-WinRM/Operational]
disabled = 0
index = windows
sourcetype = WinEventLog:WinRM

[WinEventLog://Microsoft-Windows-WMI-Activity/Operational]
disabled = 0
index = windows
sourcetype = WinEventLog:WMI

[WinEventLog://Microsoft-Windows-SMBServer/Operational]
disabled = 0
index = windows
sourcetype = WinEventLog:SMB

[WinEventLog://Microsoft-Windows-TaskScheduler/Operational]
disabled = 0
index = windows
sourcetype = WinEventLog:TaskScheduler

# -----------------------------------------------------------------------------
# Scored Services
# -----------------------------------------------------------------------------

# This doesn't work :(
[WinEventLog://Microsoft-Windows-DNSServer/Analytical]
disabled = 0
index = windows
renderXml = 1
sourcetype = msdns:analytical

[monitor://C:\Windows\System32\dns\dns*.log]
disabled = 0
index = windows
sourcetype = ms:dns:debug

[monitor://C:\inetpub\logs\LogFiles\W3SVC*\*.log]
disabled = 0
index = windows
sourcetype = ms:iis:auto

[monitor://C:\inetpub\logs\LogFiles\FTPSVC*\*.log]
disabled = 0
index = windows
sourcetype = ms:iis:auto
"@ | Out-File -FilePath $inputsConfPath -Encoding ASCII

# Configure server.conf to use the specified hostname
$serverConfPath = "$INSTALL_DIR\etc\system\local\server.conf"
Write-Host "Setting custom hostname for the logs to '$SplunkHostname'..."
# The $SplunkHostname variable will be pulled from the parameters
@"
[general]
serverName = $SplunkHostname
hostnameOption = shortname
"@ | Out-File -FilePath $serverConfPath -Encoding ASCII

# Restart Splunk Universal Forwarder service to load new inputs.conf
# The MSI installer already starts the service and sets it to auto-start.
# We need a restart to pick up the inputs.conf and server.conf we just wrote.
Write-Host "Restarting Splunk Universal Forwarder service to load configuration..."
Restart-Service SplunkForwarder -Force

# Verify the service is running
Start-Sleep -Seconds 5
$svc = Get-Service SplunkForwarder -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq "Running") {
    Write-Host "[OK] SplunkForwarder service is running" -ForegroundColor Green
} else {
    Write-Host "[WARN] SplunkForwarder service is not running - check Event Viewer" -ForegroundColor Yellow
}

Write-Host "Splunk Universal Forwarder installation and configuration complete!"
} #splunk
    Write-Host "========================================"
    Write-Host "|       Installing Splunk              |"
    Write-Host "========================================"
    agentsetup-splunk
    Write-Host "Splunk Install Complete" -ForegroundColor DarkMagenta

    Write-Host "========================================"
    Write-Host "|       Installing Wazuh              |"
    Write-Host "========================================"
    agentsetup-wazuh
    Write-Host "Wazuh Install Complete" -ForegroundColor DarkMagenta

    Write-Host "========================================"
    Write-Host "|       Installing Salt              |"
    Write-Host "========================================"
    agentsetup-salt
    Write-Host "Salt Install Complete" -ForegroundColor DarkMagenta

} #Choice 6
agent-setup