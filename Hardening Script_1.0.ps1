#--------------------------------------------------------------
#  Script Hardening | Downloads all are tools for comp
# Branched from All in one | Script for start of comp | Version | 1.26.5
# Made by Logan Schultz
#Version | 1.0
#--------------------------------------------------------------
$ProgressPreference = 'SilentlyContinue'
function Hardening {
    function hard-zerologon {
        #----------------------------------------------------------
        # Prevent Zerologon
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|          Zerologon Hardening         |"
        Write-Host "========================================"

        Write-Host "Applying Zerologon protection..."
        Remove-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters' -Name 'FullSecureChannelProtection' -Force -ErrorAction SilentlyContinue
        New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters' -Name 'FullSecureChannelProtection' -Value 1 -PropertyType DWORD -Force -ErrorAction SilentlyContinue
        Write-Host "Zerologon Fixed" -ForegroundColor DarkMagenta
    }
    function hard-SMB {
        #----------------------------------------------------------
        # SMB Hardening
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|          SMB Hardening               |"
        Write-Host "========================================"

        Write-Host "Hardening SMB..."
        # Disable SMBv1
        Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name SMB1 -Type DWORD -Value 0 -Force

        # Enable SMBv2 with security
        Set-SmbServerConfiguration -EnableSMB2Protocol $true -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name SMB2 -Type DWORD -Value 1 -Force

        # SMB Security Signatures (require signing)
        reg add "HKLM\System\CurrentControlSet\Services\LanManWorkstation\Parameters" /v RequireSecuritySignature /t REG_DWORD /d 1 /f 2>$null
        reg add "HKLM\System\CurrentControlSet\Services\LanManWorkstation\Parameters" /v EnableSecuritySignature /t REG_DWORD /d 1 /f 2>$null
        reg add "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" /v RequireSecuritySignature /t REG_DWORD /d 1 /f 2>$null
        reg add "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" /v EnableSecuritySignature /t REG_DWORD /d 1 /f 2>$null

        # Disable admin shares on non-DC machines (breaks GP distribution on DCs)
        $domainRole = (Get-WmiObject Win32_ComputerSystem).DomainRole
        if ($domainRole -lt 4) {
            # Not a DC (0=Standalone WS, 1=Member WS, 2=Standalone Server, 3=Member Server)
            reg add "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" /v AutoShareServer /t REG_DWORD /d 0 /f 2>$null
            reg add "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" /v AutoShareWks /t REG_DWORD /d 0 /f 2>$null
        } else {
            Write-Host "  Skipping admin share disable (Domain Controller detected)" -ForegroundColor Yellow
        }

        # Require SMB encryption (note: Enable-NetworkVisibility.ps1 disables this for Zeek - run that script last if using Zeek)
        reg add "HKLM\System\CurrentControlSet\Services\LanmanServer\Parameters" /v RejectUnencryptedAccess /t REG_DWORD /d 1 /f 2>$null
        Write-Host "SMB Fixed" -ForegroundColor DarkMagenta
    }
    function hard-TLS {
        #----------------------------------------------------------
        # TLS 1.2
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|         Enabling TLS 1.2             |"
        Write-Host "========================================"
        Write-Host "Enabling TLS 1.2..."
        New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -Force -ErrorAction SilentlyContinue | Out-Null
        New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -Name 'Enabled' -Value 1 -PropertyType DWORD -Force | Out-Null
        New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server' -Name 'DisabledByDefault' -Value 0 -PropertyType DWORD -Force | Out-Null
        New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -Force -ErrorAction SilentlyContinue | Out-Null
        New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -Name 'Enabled' -Value 1 -PropertyType DWORD -Force | Out-Null
        New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client' -Name 'DisabledByDefault' -Value 0 -PropertyType DWORD -Force | Out-Null
        #[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
    function hard-windows-updates {
        #----------------------------------------------------------
        # Windows Updates
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|      Fixing Windows Updates          |"
        Write-Host "========================================"
        Set-Service -Name wuauserv -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AutoInstallMinorUpdates /t REG_DWORD /d 1 /f 2>$null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 0 /f 2>$null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 4 /f 2>$null
    }
    function hard-windows-defender {
        #----------------------------------------------------------
        # Windows Defender
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|    Hardening Windows Defender        |"
        Write-Host "========================================"
        Start-Service WinDefend -ErrorAction SilentlyContinue
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d 0 /f 2>$null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiVirus" /t REG_DWORD /d 0 /f 2>$null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "ServiceKeepAlive" /t REG_DWORD /d 1 /f 2>$null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" /v "DisableRealtimeMonitoring" /t REG_DWORD /d 0 /f 2>$null

        try {
            Set-MpPreference -DisableRealtimeMonitoring $false -DisableBehaviorMonitoring $false -DisableIOAVProtection $false -DisableScriptScanning $false -EnableControlledFolderAccess Enabled -EnableNetworkProtection Enabled -SubmitSamplesConsent NeverSend -ErrorAction SilentlyContinue
        } catch {}
    }
    function hard-disable-autorun {
        #----------------------------------------------------------
        # Disable autorun
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|        Disabling AutoRuns            |"
        Write-Host "========================================"
        Write-Host "Disabling autorun..."
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoAutorun" /t REG_DWORD /d 1 /f 2>$null
        reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoDriveTypeAutoRun" /t REG_DWORD /d 255 /f 2>$null
    }
    function hard-disable-cortana-and-web-search {
        #----------------------------------------------------------
        # Disable Cortana and web search
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|    Disable Cortana & Web Search      |"
        Write-Host "========================================"
        Write-Host "Disabling Cortana and web search..."
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "AllowCortana" /t REG_DWORD /d 0 /f 2>$null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "AllowCortanaAboveLock" /t REG_DWORD /d 0 /f 2>$null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "DisableWebSearch" /t REG_DWORD /d 1 /f 2>$null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v "ConnectedSearchUseWeb" /t REG_DWORD /d 0 /f 2>$null
    }
    function hard-disable-dangerous-features {
        #----------------------------------------------------------
        # Disable dangerous features (if they exist)
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|     Disable Telnet,SMB1 and TFTP     |"
        Write-Host "========================================"

        Write-Host "Disabling dangerous features..."
        @('TFTP', 'TelnetClient', 'TelnetServer', 'SMB1Protocol') | ForEach-Object {
            $feature = Get-WindowsOptionalFeature -Online -FeatureName $_ -ErrorAction SilentlyContinue
            if ($feature -and $feature.State -eq 'Enabled') {
                Disable-WindowsOptionalFeature -Online -FeatureName $_ -NoRestart -ErrorAction SilentlyContinue | Out-Null
           }
       }
    }
    function hard-disable-dangerous-services {
        #----------------------------------------------------------
        # Disable dangerous services
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|       Disable Remote Registry        |"
        Write-Host "========================================"
        Write-Host "Disabling dangerous services..."
        @('Spooler', 'RemoteRegistry') | ForEach-Object {
            Stop-Service -Name $_ -Force -ErrorAction SilentlyContinue
            Set-Service -Name $_ -StartupType Disabled -ErrorAction SilentlyContinue
        }
    }
    function hard-remove-accessibility-backdoors {
        #----------------------------------------------------------
        move accessibility backdoors
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|     Remove Accessibility Backdoors   |"
        Write-Host "========================================"

        Write-Host "Removing accessibility backdoors (IFEO debugger entries)..."
        @('sethc.exe', 'Utilman.exe', 'osk.exe', 'Narrator.exe', 'Magnify.exe') | ForEach-Object {
            reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$_" /v Debugger /f 2>$null
        }
    }
    function hard-DEP {
        #----------------------------------------------------------
        # Enable DEP (Data Execution Prevention)
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|          Enable DEP                  |"
        Write-Host "========================================"

        Write-Host "Enabling DEP..."
        bcdedit.exe /set "{current}" nx AlwaysOn 2>$null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v "NoDataExecutionPrevention" /t REG_DWORD /d 0 /f 2>$null
        reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v "DisableHHDEP" /t REG_DWORD /d 0 /f 2>$null
    }
    function hard-password-policies {
        #----------------------------------------------------------
        # Password policies
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|     Hardening Password Pol           |"
        Write-Host "========================================"
        Write-Host "Enforcing password policies..."
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LimitBlankPasswordUse /t REG_DWORD /d 1 /f 2>$null
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_DWORD /d 0 /f 2>$null
    }
    function hard-show-hidden-files-and-extesions {
        #----------------------------------------------------------
        # Show hidden files and extensions
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|    Show Hidden Files and extesions   |"
        Write-Host "========================================"

        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f 2>$null
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f 2>$null
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowSuperHidden /t REG_DWORD /d 1 /f 2>$null
    }
    function hard-RDP {
        #----------------------------------------------------------
        # RDP Hardening
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|          RDP Hardening               |"
        Write-Host "========================================"

        # Require Network Level Authentication
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -Value 1 -Type DWord -Force
        # Set security layer to TLS
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "SecurityLayer" -Value 2 -Type DWord -Force

        # Session timeouts and redirection restrictions
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "MaxIdleTime" -Value 1800000 -Type DWord -Force
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "MaxDisconnectionTime" -Value 900000 -Type DWord -Force
        # Disable drive and clipboard redirection
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "fDisableCdm" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "fDisableClip" -Value 1 -Type DWord -Force
    }
    function hard-comprehensive-audit-logging {
        #----------------------------------------------------------
        # Comprehensive Audit Logging
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|     Comprehensive audit logging      |"
        Write-Host "========================================"

        auditpol /set /category:* /success:enable /failure:enable 2>$null

        # Key subcategories
        @(
            "Security State Change", "Security System Extension", "System Integrity",
            "Logon", "Logoff", "Account Lockout", "Special Logon",
            "Process Creation", "Process Termination",
            "File System", "Registry", "SAM",
            "User Account Management", "Security Group Management",
            "Audit Policy Change", "Authentication Policy Change",
            "Credential Validation", "Kerberos Authentication Service"
        ) | ForEach-Object {
            auditpol /set /subcategory:"$_" /success:enable /failure:enable 2>$null
        }
    }
    function hard-powershell-logging {
        #----------------------------------------------------------
        # PowerShell Logging (Registry-based GPO - cannot be bypassed with -NoProfile)
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|    Hardening Powershell logging      |"
        Write-Host "========================================"

        Write-Host "Enabling PowerShell logging via registry GPO..."

        # ScriptBlock logging
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 1 -Type DWord -Force

        # Module logging (log all modules)
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging" -Name "EnableModuleLogging" -Value 1 -Type DWord -Force
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames" -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging\ModuleNames" -Name "*" -Value "*" -Type String -Force

        # Transcription (registry-based, belt-and-suspenders with profile-based below)
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name "EnableTranscripting" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name "OutputDirectory" -Value "C:\Windows\Logs\PSTranscripts" -Type String -Force
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name "EnableInvocationHeader" -Value 1 -Type DWord -Force
        New-Item -ItemType Directory -Path "C:\Windows\Logs\PSTranscripts" -Force | Out-Null
    }
    function hard-commandline-events {
        Write-Host "========================================"
        Write-Host "|          Command-line Hardening      |"
        Write-Host "========================================"
        #----------------------------------------------------------
        # Command-Line in Process Creation Events (Event 4688)
        #----------------------------------------------------------
        Write-Host "Enabling command-line in process creation events..."
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" -Name "ProcessCreationIncludeCmdLine_Enabled" -Value 1 -Type DWord -Force

        #----------------------------------------------------------
        # Credential Protection (WDigest, LSA Protection, Cached Logons)
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|   Hardening  Credential Protection   |"
        Write-Host "========================================"
        Write-Host "Hardening credential protection..."

        # Disable WDigest (prevents cleartext passwords in memory)
        Write-Host "========================================"
        Write-Host "|          Disable WDigest             |" 
        Write-Host "========================================"
        New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -Name "UseLogonCredential" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -Name "Negotiate" -Value 0 -Type DWord -Force
         Write-Host "========================================"
        Write-Host "|          Enable LSA Protection        |"
        Write-Host "========================================="
        # Enable LSA Protection (blocks Mimikatz from reading LSASS)
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 1 -Type DWord -Force

        # Reduce cached logons (default is 10, reduce to 2)
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "CachedLogonsCount" -Value "2" -Type String -Force
    }
    function hard-disable-LLMNR-NBT-NS-mDNS {
        #----------------------------------------------------------
        # Disable LLMNR / NBT-NS / mDNS (anti-Responder)
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|     Disable LLMNR/NBT/mDNS           |" 
        Write-Host "========================================"
        Write-Host "Disabling LLMNR, NBT-NS, and mDNS..."

        # Disable LLMNR
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" -Name "EnableMulticast" -Value 0 -Type DWord -Force

        # Disable NBT-NS on all adapters
        $adapters = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "IPEnabled=true"
        foreach ($adapter in $adapters) {
            $adapter.SetTcpipNetbios(2) | Out-Null  # 2 = Disable NetBIOS over TCP/IP
        }
    }
    function hard-enhanced-windows-defender {
        #----------------------------------------------------------
        # Enhanced Windows Defender (ASR Rules)
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|    Hardening Windows Defender        |"
        Write-Host "========================================"
        Write-Host "Configuring enhanced Windows Defender with ASR rules..."
        try {
            Set-MpPreference -MAPSReporting Advanced -ErrorAction SilentlyContinue
            Set-MpPreference -PUAProtection 1 -ErrorAction SilentlyContinue

            # Attack Surface Reduction rules (Block mode = 1)
            $asrRules = @(
                "9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2",  # Block credential stealing from LSASS
                "d1e49aac-8f56-4280-b9ba-993a6d77406c",  # Block process creations from PSExec/WMI
                "b2b3f03d-6a65-4f7b-a9c7-1c7ef74a9ba4",  # Block untrusted unsigned processes from USB
                "56a863a9-875e-4185-98a7-b882c64b5ce5",  # Block abuse of exploited vulnerable signed drivers
                "e6db77e5-3df2-4cf1-b95a-636979351e5b",  # Block persistence through WMI event subscription
                "5BEB7EFE-FD9A-4556-801D-275E5FFC04CC",  # Block execution of potentially obfuscated scripts
                "D4F940AB-401B-4EFC-AADC-AD5F3C50688A",  # Block Office apps from creating child processes
                "7674ba52-37eb-4a4f-a9a1-f0f9a1619a2c"   # Block Adobe Reader from creating child processes
            )
            $asrActions = @(1, 1, 1, 1, 1, 1, 1, 1)  # All in Block mode
            Set-MpPreference -AttackSurfaceReductionRules_Ids $asrRules -AttackSurfaceReductionRules_Actions $asrActions -ErrorAction SilentlyContinue
        } catch {
            Write-Host "  [WARN] Some Defender features may not be available on this edition" -ForegroundColor Yellow
        }
    }
    function hard-powershell-logging-profile-based {
        Write-Host "========================================"
        Write-Host "|    Profile based Powershell logging  |"
        Write-Host "========================================"
            #----------------------------------------------------------
            # PowerShell Transcript Logging (Profile-based)
            #----------------------------------------------------------
            Write-Host "Enabling PowerShell transcript logging..."
            $transcriptContent = @'
        $path = "C:\Windows\Logs\"
        $username = $env:USERNAME
        $hostname = hostname
        $datetime = Get-Date -f 'MM/dd-HH:mm:ss'
        $filename = "transcript-${username}-${hostname}-${datetime}.txt"
        $Transcript = Join-Path -Path $path -ChildPath $filename
        Start-Transcript -Path $Transcript -Append
'@
    New-Item -Path $profile.AllUsersCurrentHost -Type File -Force -ErrorAction SilentlyContinue | Out-Null
    Set-Content -Path $profile.AllUsersCurrentHost -Value $transcriptContent -Force -ErrorAction SilentlyContinue
    }
    function hard-clean-startup-locations {
        #----------------------------------------------------------
        # Cleanup startup locations
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|    Cleaning Startup locations        |"
        Write-Host "========================================"
        Write-Host "Cleaning startup locations..."
        @(
            'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\*',
            "C:\Users\*\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\*"
        ) | ForEach-Object {
            $items = Get-ChildItem $_ -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                Write-Host "  Removing startup item: $($item.FullName)" -ForegroundColor Yellow
            }
            Remove-Item -Path $_ -Force -ErrorAction SilentlyContinue
        }
    }
    function hard-flush-dns {
        Write-Host "========================================"
        Write-Host "|             Flushing DNS             |"
        Write-Host "========================================"
        # Flush DNS
        ipconfig /flushdns 2>$null | Out-Null
    }
    function hard-disable-IPV6 {
        #----------------------------------------------------------
        #Disable IPV6
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|            Disabling IPV6            |"
        Write-Host "========================================"
        Write-Host "Disabling IPV6..."
        #Disable IPV6 on NIC
        Disable-NetAdapterBinding -Name "Ethernet" -ComponentID "ms_tcpip6" -Confirm:$false

        #Disable IPV6 Registry
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -Value 0xFF
    }
    function hard-WINRM {
        #----------------------------------------------------------
        # Stop WINRM
        #----------------------------------------------------------
        Write-Host "========================================"
        Write-Host "|          Hardening WindRM            |"
        Write-Host "========================================"
        #Stop the Service
        Stop-Service WinRM
        Set-Service WinRM -StartupType Disabled

        #Remove WinRM Listeners: This ensures the system stops "listening" for management requests on any port.
        #Get-ChildItem -Path WSMan:\localhost\Listener | Remove-Item -Recurse
    }
    function hard-stop-Print-Spooler {
        Write-Host "========================================"
        Write-Host "|    Hardening Print Spooler           |"
        Write-Host "========================================"
        #----------------------------------------------------------
        # Stop Print Spooler
        #----------------------------------------------------------
        Stop-Service -Name "Spooler" -Force
        Set-Service -Name "Spooler" -StartupType Disabled

        #Reg Disable of Print spooler
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Spooler" -Name "Start" -Value 4
    }
    function hard-remove-NJRAT {
        Write-Host "========================================"
        Write-Host "|          Removing NJRAT              |"
        Write-Host "========================================"
        #Remove NJRAT
        #----------------------------------------------------------

        #Reg key one
        if (Test-Path -Path "HKU\S-1-5-21-1605714558-552561641-297346831-500\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\84936d0927c52cbf1a9c1029911fc028") {
        Remove-ItemProperty -Path "HKU\S-1-5-21-1605714558-552561641-297346831-500\SOFTWARE\Microsoft\Windows\CurrentVersion\Run\84936d0927c52cbf1a9c1029911fc028"
        Write-Host "NJRat Registry key deleted | First key." -ForegroundColor DarkRed
        } else {
        Write-Host "First NJRat Registry key does not exist." -ForegroundColor Green
        }

        #Reg key two
            if (Test-Path -Path "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run\84936d0927c52cbf1a9c1029911fc028") {
        Remove-ItemProperty -Path "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run\84936d0927c52cbf1a9c1029911fc028"
        Write-Host "NJRat Registry key deleted | Second Key." -ForegroundColor DarkRed
        } else {
        Write-Host "Second NJRat Registry key does not exist." -ForegroundColor Green
        }
    }
    function hard-disable-hyper-v {
        Write-Host "========================================"
        Write-Host "|         Hardening Hyper-V            |"
        Write-Host "========================================"
        Get-WindowsFeature
        #Disable Hyper V
        #---------------------------------------------------------- 
        if ((Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All").State -eq 'Enabled') { 
        Write-Host "Hyper V Enable, Disableing now" -ForegroundColor DarkRed 
        Disable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -NoRestart -Confirm:$false
        Write-Host "Hyper V Server Disabled" -ForegroundColor Green
        } else { 
            Write-Host "Hyper V not Enabled" -ForegroundColor Green
        }
    }
    function hard-disable-dhcp-server {
        Write-Host "========================================"
        Write-Host "|         Hardening DHCP               |"
        Write-Host "========================================"

        Get-WindowsFeature
        #Disable DHCP Server
        #----------------------------------------------------------
        if ((Get-WindowsOptionalFeature -Online -FeatureName "DHCPServer").State -eq 'Enabled') { 
        Write-Host "DHCP Server Enable, Disableing now"  -ForegroundColor DarkRed 
        Disable-WindowsOptionalFeature -Online -FeatureName "DHCPServer" -NoRestart -Confirm:$false
        Write-Host "DHCP Server Disabled" -ForegroundColor Green
        } else { 
        Write-Host "DHCP Server not Enabled" -ForegroundColor Green
        }
    }
    function hard-disable-fax-server {
        Write-Host "========================================"
        Write-Host "|         Hardening Fax Server         |"
        Write-Host "========================================"
        #Disable Fax Server
        #----------------------------------------------------------
        if ((Get-WindowsOptionalFeature -Online -FeatureName "FaxServer").State -eq 'Enabled') { 
        Write-Host "Fax Server Enable, Disableing now" -ForegroundColor DarkRed
        Disable-WindowsOptionalFeature -Online -FeatureName "FaxServer" -NoRestart -Confirm:$false
        Write-Host "Fax Server Disabled" -ForegroundColor Green
        } else { 
        Write-Host "Fax Server not Enabled" -ForegroundColor Green
        }
    
        Write-Host "[OK] Hardening complete" -ForegroundColor Green
    }
    function hard-disable-event-Scheduler {
        Write-Host "========================================"
        Write-Host "|      Disabling Event Scheduler       |"
        Write-Host "========================================"
        #powershell command to delete registy for startup system
        reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule" /v YourValueName /t REG_DWORD /d 4 /f
        #NOT TESTED

    }
Write-Host "========================================"
Write-Host "|          System Hardening            |"
Write-Host "========================================"

#Call all harding
#hard-disable-event-Scheduler
hard-zerologon
hard-SMB
hard-TLS
hard-windows-updates
hard-windows-defender
hard-disable-autorun
hard-disable-cortana-and-web-search
hard-disable-dangerous-features
hard-disable-dangerous-services
hard-remove-accessibility-backdoors
hard-DEP
hard-password-policies
hard-show-hidden-files-and-extesions
#hard-RDP
hard-comprehensive-audit-logging
hard-powershell-logging
hard-commandline-events
hard-disable-LLMNR-NBT-NS-mDNS
hard-enhanced-windows-defender
hard-powershell-logging-profile-based
hard-clean-startup-locations
hard-flush-dns
hard-disable-IPV6
hard-flush-dns
#hard-WINRM
hard-stop-Print-Spooler
hard-remove-NJRAT
hard-disable-hyper-v
hard-disable-dhcp-server
hard-disable-fax-server


Write-Host "-----------------------------------------" -ForegroundColor Green
Write-Host "|         Hardening complete            |" -ForegroundColor Green
Write-Host "-----------------------------------------" -ForegroundColor Green
}# Choice two
Hardening