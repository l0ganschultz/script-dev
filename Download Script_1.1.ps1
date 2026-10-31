#--------------------------------------------------------------
# Download Script | Downloads all are tools for comp
# Branched from All in one | Script for start of comp | Version | 1.26.5
# Made by Logan Schultz
#Version | 1.1
#--------------------------------------------------------------
$ProgressPreference = 'SilentlyContinue'
function download {


    function Download-Sysinternals {
            Write-Host "========================================"
            Write-Host "|       Downloading Sysinternals       |"
            Write-Host "========================================"
            # Create extract folder | Sysinternals
            $extractPathSY = "C:\Sysinternals"
            if (!(Test-Path $extractPathSY)) {
            New-Item -ItemType Directory -Path $extractPathSY | Out-Null
            }

            Write-Host "Starting download of Sysinternals" -ForegroundColor DarkMagenta

            # Sysinternals
            $urlSY = "https://download.sysinternals.com/files/SysinternalsSuite.zip"
            $downloadPathSY = "C:\Users\$env:USERNAME\Downloads\SysinternalsSuite.zip"


            # Download Sysinternals
            Start-BitsTransfer -Source $urlSY -Destination $downloadPathSY 
            Write-Host "Extracting ZIP file of Sysinternals" -ForegroundColor DarkMagenta
            # Extract Sysinternals
            Expand-Archive -Path $downloadPathSY -DestinationPath $extractPathSY -Force

            Write-Host "Tool Setup Sysinternals" -ForegroundColor Green
    
    }
    function Download-Everthing {
            # everthing
            #-------------------------------------------------------------- 
            Write-Host "========================================"
            Write-Host "|       Downloading Everthing          |"
            Write-Host "========================================"

            # everthing
            $url_everthing = "https://www.voidtools.com/Everything-1.4.1.1032.x86-Setup.exe"
            $downloadPatheverthing = "C:\Users\$env:USERNAME\Downloads\Everything-1.4.1.1032.x86-Setup.exe"
            Write-Host "Starting download of Everthing" -ForegroundColor DarkMagenta
            # Download Everthing
            Start-BitsTransfer -Source $url_everthing -Destination $downloadPatheverthing
            Write-Host "Download of Everthing complete" -ForegroundColor Green
    }
    function Download-System-Informer {
            # System Informer
            #-------------------------------------------------------------- 
            Write-Host "========================================"
            Write-Host "|         System Informer              |"
            Write-Host "========================================"
            # Sysinternals
            $url_systeminformer = "https://github.com/winsiderss/systeminformer/releases/download/v3.2.25011.2103/systeminformer-3.2.25011-release-setup.exe"
            $downloadPathsysteminformer = "C:\Users\$env:USERNAME\Downloads\systeminformer-3.2.25011-release-setup.exe"

            Write-Host "Starting Download of System Informer" -ForegroundColor DarkMagenta
            # Download Everthing
            Start-BitsTransfer -Source $url_systeminformer -Destination $downloadPathsysteminformer
            Write-Host "Download of System Informer complete" -ForegroundColor Green
    }
    function Download-RootKit-Revealer {
            # Root Kit Revealer
            #-------------------------------------------------------------- 
            Write-Host "========================================"
            Write-Host "|    Downloading RootKit Revealer      |"
            Write-Host "========================================"
            $extractPathrootkitrevealer = "C:\Rootkitzip"
            # Create extract folder | Sysmon
            if (!(Test-Path $extractPathrootkitrevealer)) {
            New-Item -ItemType Directory -Path $extractPathrootkitrevealer | Out-Null
            }
            # Sysinternals
            $url_rootkitrevealer = "https://download.sysinternals.com/files/RootkitRevealer.zip"
            $downloadPath_rootkitrevealer = "C:\Users\$env:USERNAME\Downloads\RootkitRevealer.zip"

            Write-Host "Starting Download of RootKit Revealer" -ForegroundColor DarkMagenta
            # Download RootKit Revealer
            Start-BitsTransfer -Source $url_rootkitrevealer -Destination $downloadPath_rootkitrevealer

            Write-Host "Extracting ZIP file of Root Kit Revealer" -ForegroundColor  DarkMagenta
            # Extract RootKit Revealer
            Expand-Archive -Path $downloadPath_rootkitrevealer -DestinationPath $extractPathrootkitrevealer -Force

            Write-Host "Download of RootKit Revealer complete" -ForegroundColor Green
    }
    function Download-7-zip {
            # 7 zip
            #-------------------------------------------------------------- 
            Write-Host "========================================"
            Write-Host "|          Downloading 7 zip            |"
            Write-Host "========================================"
            #7 zip
            $url_7zip = "https://www.7-zip.org/a/7z2600-x64.exe"
            $downloadPath7zip = "C:\Users\$env:USERNAME\Downloads\7z2600-x64.exe"

            # Download 7zip
            Start-BitsTransfer -Source $url_7zip -Destination $downloadPath7zip
    }
    function Download-Malware-bytes {
            # Malware Bytes
            #-------------------------------------------------------------- 
            Write-Host "========================================"
            Write-Host "|     Downloading Malware Bytes        |"
            Write-Host "========================================"

            # Malware Bytes
            $url_malwarebytes = "https://data-cdn.mbamupdates.com/web/mb5-setup-consumer/MBSetup.exe"
            $downloadmalwarebytes = "C:\Users\$env:USERNAME\Downloads\MBSetup.exe"
            Write-Host "Starting download of Malware bytes" -ForegroundColor DarkMagenta
            # Download Malware Bytes
            Start-BitsTransfer -Source $url_malwarebytes -Destination $downloadmalwarebytes
            Write-Host "Download of Malwarebytes complete" -ForegroundColor Green
    }
        function Download-install-Sysmon{
            param (
            # Optional: Path to a local Sysmon XML config file. Skips config download if provided.
            [string]$ConfigPath,

            # Optional: Directory where Sysmon binaries are placed.
            [string]$InstallDir = "C:\Sysmon"
            )

            # PowerShell script to install and configure Sysmon with Olaf Hartong's sysmon-modular config.
            # Falls back to SwiftOnSecurity if the primary config is unavailable.
            # Provide -ConfigPath to skip the download entirely and use your own XML.
            #
            # Made by Samuel Brucker 2024 - 2026

            $ErrorActionPreference = "Stop"

            # -- Variables ----------------------------------------------------------------
            $SysmonZipUrl    = "https://download.sysinternals.com/files/Sysmon.zip"
            $SysmonZipPath   = Join-Path $InstallDir "Sysmon.zip"
            $SysmonExe       = Join-Path $InstallDir "Sysmon64.exe"
            $DefaultConfig   = Join-Path $InstallDir "sysmonconfig.xml"

            $PrimaryConfigUrl  = "https://raw.githubusercontent.com/olafhartong/sysmon-modular/master/sysmonconfig.xml"
            $FallbackConfigUrl = "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml"

            # -- 1. Admin check -----------------------------------------------------------
            $principal = New-Object Security.Principal.WindowsPrincipal(
                [Security.Principal.WindowsIdentity]::GetCurrent()
            )
            if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                Write-Host "[ERROR] This script must be run as Administrator." -ForegroundColor Red
                exit 1
            }
            Write-Host "[OK] Running as Administrator." -ForegroundColor Green

            # -- 2. Create install directory -----------------------------------------------
            if (-not (Test-Path $InstallDir)) {
                New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
                Write-Host "[OK] Created install directory: $InstallDir" -ForegroundColor Green
            } else {
                Write-Host "[OK] Install directory exists: $InstallDir" -ForegroundColor Green
            }

            # -- 3. Download Sysmon --------------------------------------------------------
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            $ProgressPreference = 'SilentlyContinue'

            if (Test-Path $SysmonExe) {
                Write-Host "[OK] Sysmon64.exe already present at $SysmonExe" -ForegroundColor Green
            } else {
                Write-Host "Downloading Sysmon from $SysmonZipUrl ..."
                try {
                    Invoke-WebRequest -Uri $SysmonZipUrl -OutFile $SysmonZipPath -UseBasicParsing
                } catch {
                    Write-Host "[ERROR] Failed to download Sysmon: $_" -ForegroundColor Red
                    exit 1
                }

                Write-Host "Extracting Sysmon.zip ..."
                try {
                    Expand-Archive -Path $SysmonZipPath -DestinationPath $InstallDir -Force
                } catch {
                    Write-Host "[ERROR] Failed to extract Sysmon.zip: $_" -ForegroundColor Red
                    exit 1
                }
                Remove-Item $SysmonZipPath -Force -ErrorAction SilentlyContinue

                if (-not (Test-Path $SysmonExe)) {
                    Write-Host "[ERROR] Sysmon64.exe not found after extraction. Check $InstallDir contents." -ForegroundColor Red
                    exit 1
                }
                Write-Host "[OK] Sysmon64.exe extracted to $InstallDir" -ForegroundColor Green
            }

            # -- 4. Download config --------------------------------------------------------
            $ActiveConfig = ""

            if ($ConfigPath) {
                if (-not (Test-Path $ConfigPath)) {
                    Write-Host "[ERROR] Specified config not found: $ConfigPath" -ForegroundColor Red
                    exit 1
                }
                $ActiveConfig = $ConfigPath
                Write-Host "[OK] Using provided config: $ActiveConfig" -ForegroundColor Green
            } else {
                # Primary: Olaf Hartong sysmon-modular
                Write-Host "Downloading Olaf Hartong sysmon-modular config ..."
                try {
                    Invoke-WebRequest -Uri $PrimaryConfigUrl -OutFile $DefaultConfig -UseBasicParsing
                    $ActiveConfig = $DefaultConfig
                    Write-Host "[OK] sysmon-modular config downloaded to $ActiveConfig" -ForegroundColor Green
                } catch {
                    Write-Host "[WARN] Failed to download sysmon-modular config: $_" -ForegroundColor Yellow
                    # Fallback: SwiftOnSecurity
                    Write-Host "Downloading SwiftOnSecurity fallback config ..."
                    try {
                       Invoke-WebRequest -Uri $FallbackConfigUrl -OutFile $DefaultConfig -UseBasicParsing
                        $ActiveConfig = $DefaultConfig
                        Write-Host "[OK] SwiftOnSecurity config downloaded to $ActiveConfig" -ForegroundColor Green
                    } catch {
                        Write-Host "[ERROR] Failed to download any config. Provide one with -ConfigPath." -ForegroundColor Red
                        exit 1
                    }
                }
            }

            # -- 5. Accept EULA ------------------------------------------------------------
            Write-Host "Accepting Sysinternals EULA via registry ..."
            $eulaKey = "HKCU:\Software\Sysinternals\Sysmon64"
            if (-not (Test-Path $eulaKey)) {
                New-Item -Path $eulaKey -Force | Out-Null
            }
            Set-ItemProperty -Path $eulaKey -Name "EulaAccepted" -Value 1 -Type DWord
            Write-Host "[OK] EULA accepted." -ForegroundColor Green

            # -- 6. Install or update ------------------------------------------------------
            $svc = Get-Service -Name "Sysmon64" -ErrorAction SilentlyContinue

            if ($svc) {
                Write-Host "Sysmon64 service exists - updating configuration ..."
                $ErrorActionPreference = "Continue"
                & $SysmonExe -c $ActiveConfig 2>&1 | ForEach-Object { Write-Host "    $_" }
                $sysmonExit = $LASTEXITCODE
                $ErrorActionPreference = "Stop"
                if ($sysmonExit -ne 0) {
                    Write-Host "[ERROR] Sysmon config update returned exit code $sysmonExit" -ForegroundColor Red
                    exit 1
                }
                Write-Host "[OK] Sysmon configuration updated." -ForegroundColor Green
            } else {
                Write-Host "Installing Sysmon64 ..."
                $ErrorActionPreference = "Continue"
                & $SysmonExe -accepteula -i $ActiveConfig 2>&1 | ForEach-Object { Write-Host "    $_" }
                $sysmonExit = $LASTEXITCODE
                $ErrorActionPreference = "Stop"
                if ($sysmonExit -ne 0) {
                    Write-Host "[ERROR] Sysmon installation returned exit code $sysmonExit" -ForegroundColor Red
                    exit 1
                }
                Write-Host "[OK] Sysmon installed successfully." -ForegroundColor Green
            }

            # -- 7. Verify -----------------------------------------------------------------
            Write-Host "Verifying Sysmon service ..."
            $svc = Get-Service -Name "Sysmon64" -ErrorAction SilentlyContinue
            if (-not $svc -or $svc.Status -ne "Running") {
                Write-Host "[ERROR] Sysmon64 service is not running!" -ForegroundColor Red
                exit 1
            }
            Write-Host "[OK] Sysmon64 service is running." -ForegroundColor Green

            Start-Sleep -Seconds 2
            try {
                $events = Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 5 -ErrorAction Stop
                Write-Host "[OK] Found $($events.Count) recent Sysmon event(s) in the log." -ForegroundColor Green
                } catch {
                Write-Host "[WARN] No Sysmon events found yet (may take a moment): $_" -ForegroundColor Yellow
            }

            # -- 8. Summary ----------------------------------------------------------------
            Write-Host ""
            Write-Host "=== Sysmon Installation Summary ===" -ForegroundColor Cyan
            Write-Host "  Binary:  $SysmonExe"
            Write-Host "  Config:  $ActiveConfig"
            Write-Host "  Service: $($svc.Status)"
            Write-Host "  Log:     Microsoft-Windows-Sysmon/Operational"
            Write-Host "===================================" -ForegroundColor Cyan
    }

    # add calamav to this script/ or build another one to install it / build it up.

#Call all sub functions for downloads
#Download-Github
Download-Sysinternals
Download-Everthing
Download-System-Informer
Download-RootKit-Revealer
#Download-7-zip
Download-Malware-bytes
Download-install-Sysmon
}

download