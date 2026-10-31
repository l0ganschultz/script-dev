#--------------------------------------------------------------
#  Script Old Firewalls  | Old firewall script | must add new ports
# Branched from All in one | Script for start of comp | Version | 1.26.5
# Made by Logan Schultz
#Version | 1.0
#--------------------------------------------------------------
$ProgressPreference = 'SilentlyContinue'
function Firewall-local {
    Write-Host "========================================"
    Write-Host "|        Setting up Firewalls          |"
    Write-Host "========================================"
        function firewall-base {
        Write-Host "========================================"
        Write-Host "|       Starting Firewall Base         |"
        Write-Host "========================================"
            #--------------------------------------------------------------
            # Backup existing firewall config
            #--------------------------------------------------------------
            $path = "C:\Backups\Firewall\Firewall_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').wfw"
            netsh advfirewall export $path

            #--------------------------------------------------------------
            # Disable NON-Microsoft rules only (safer than nuking everything)
            #--------------------------------------------------------------
            Get-NetFirewallRule |
            Where-Object { $_.Group -notlike "@%SystemRoot%*" } |
            Disable-NetFirewallRule

            #--------------------------------------------------------------
            # AD / DNS CORE
            #--------------------------------------------------------------

            # DNS
            Write-Host "Setting up DNS Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "DNS TCP Inbound 53" -Direction Inbound -LocalPort 53 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "DNS TCP Outbound 53" -Direction Outbound -RemotePort 53 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "DNS UDP Inbound 53" -Direction Inbound -LocalPort 53 -Protocol UDP -Action Allow
            New-NetFirewallRule -DisplayName "DNS UDP Outbound 53" -Direction Outbound -RemotePort 53 -Protocol UDP -Action Allow

            # Kerberos Authentication
            Write-Host "Setting up Kerberos Authentication Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "Kerberos TCP Inbound 88" -Direction Inbound -LocalPort 88 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "Kerberos TCP Outbound 88" -Direction Outbound -RemotePort 88 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "Kerberos UDP Inbound 88" -Direction Inbound -LocalPort 88 -Protocol UDP -Action Allow
            New-NetFirewallRule -DisplayName "Kerberos UDP Outbound 88" -Direction Outbound -RemotePort 88 -Protocol UDP -Action Allow

            # Kerberos Password Change
            Write-Host "Setting up Kerberos Password Change Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "Kerberos PW TCP Inbound 464" -Direction Inbound -LocalPort 464 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "Kerberos PW TCP Outbound 464" -Direction Outbound -RemotePort 464 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "Kerberos PW UDP Inbound 464" -Direction Inbound -LocalPort 464 -Protocol UDP -Action Allow
            New-NetFirewallRule -DisplayName "Kerberos PW UDP Outbound 464" -Direction Outbound -RemotePort 464 -Protocol UDP -Action Allow

            # LDAP
            Write-Host "Setting up LDAP Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "LDAP TCP Inbound 389" -Direction Inbound -LocalPort 389 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "LDAP TCP Outbound 389" -Direction Outbound -RemotePort 389 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "LDAP UDP Inbound 389" -Direction Inbound -LocalPort 389 -Protocol UDP -Action Allow
            New-NetFirewallRule -DisplayName "LDAP UDP Outbound 389" -Direction Outbound -RemotePort 389 -Protocol UDP -Action Allow

            # LDAPS (if enabled)
            Write-Host "Setting up LDAPS Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "LDAPS TCP Inbound 636" -Direction Inbound -LocalPort 636 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "LDAPS TCP Outbound 636" -Direction Outbound -RemotePort 636 -Protocol TCP -Action Allow

            # SMB (SYSVOL / NETLOGON)
            Write-Host "Setting up SMB Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "SMB TCP Inbound 445" -Direction Inbound -LocalPort 445 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "SMB TCP Outbound 445" -Direction Outbound -RemotePort 445 -Protocol TCP -Action Allow

            # RPC Endpoint Mapper
            Write-Host "Setting up RPC Endpoint Mapper Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "RPC TCP Inbound 135" -Direction Inbound -LocalPort 135 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "RPC TCP Outbound 135" -Direction Outbound -RemotePort 135 -Protocol TCP -Action Allow

            # RPC Dynamic Range (RESTRICTED)
            Write-Host "Setting up RPC Dynamic Range Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "RPC Dynamic TCP 5000-5100 Inbound" -Direction Inbound -LocalPort 5000-5100 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "RPC Dynamic TCP 5000-5100 Outbound" -Direction Outbound -RemotePort 5000-5100 -Protocol TCP -Action Allow

            # Time Sync
            Write-Host "Setting up Time Sync Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "W32Time UDP Inbound 123" -Direction Inbound -LocalPort 123 -Protocol UDP -Action Allow
            New-NetFirewallRule -DisplayName "W32Time UDP Outbound 123" -Direction Outbound -RemotePort 123 -Protocol UDP -Action Allow

            #--------------------------------------------------------------
            # NetBIOS (BLOCK)
            #--------------------------------------------------------------
            Write-Host "Setting up NetBIOS Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "Block NetBIOS UDP 137" -Direction Inbound -LocalPort 137 -Protocol UDP -Action Block
            New-NetFirewallRule -DisplayName "Block NetBIOS UDP 138" -Direction Inbound -LocalPort 138 -Protocol UDP -Action Block
            New-NetFirewallRule -DisplayName "Block NetBIOS TCP 139" -Direction Inbound -LocalPort 139 -Protocol TCP -Action Block

            #--------------------------------------------------------------
            # ICMP (Diagnostics)
            #--------------------------------------------------------------
            Write-Host "Setting up ICMPV4 Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "ICMPv4 Inbound" -Protocol ICMPv4 -Direction Inbound -Action Allow
            New-NetFirewallRule -DisplayName "ICMPv4 Outbound" -Protocol ICMPv4 -Direction Outbound -Action Allow

            # Block mDNS via firewall
            New-NetFirewallRule -DisplayName "Block mDNS Inbound (UDP 5353)" -Direction Inbound -LocalPort 5353 -Protocol UDP -Action Block -ErrorAction SilentlyContinue | Out-Null
            New-NetFirewallRule -DisplayName "Block mDNS Outbound (UDP 5353)" -Direction Outbound -LocalPort 5353 -Protocol UDP -Action Block -ErrorAction SilentlyContinue | Out-Null

            Write-Host "-----------------------------------------" -ForegroundColor Green
            Write-Host "|          Firewalls created            |" -ForegroundColor Green
            Write-Host "-----------------------------------------" -ForegroundColor Green
        }
        function firewall-gen {
        Write-Host "========================================"
        Write-Host "|       Starting Firewall Gen          |"
        Write-Host "========================================"
            #--------------------------------------------------------------
            # NetBIOS (BLOCK)
            #--------------------------------------------------------------
            Write-Host "Setting up NetBIOS Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "Block NetBIOS UDP 137" -Direction Inbound -LocalPort 137 -Protocol UDP -Action Block
            New-NetFirewallRule -DisplayName "Block NetBIOS UDP 138" -Direction Inbound -LocalPort 138 -Protocol UDP -Action Block
            New-NetFirewallRule -DisplayName "Block NetBIOS TCP 139" -Direction Inbound -LocalPort 139 -Protocol TCP -Action Block
            
            # DNS
            Write-Host "Setting up DNS Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "DNS TCP Inbound 53" -Direction Inbound -LocalPort 53 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "DNS TCP Outbound 53" -Direction Outbound -RemotePort 53 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "DNS UDP Inbound 53" -Direction Inbound -LocalPort 53 -Protocol UDP -Action Allow
            New-NetFirewallRule -DisplayName "DNS UDP Outbound 53" -Direction Outbound -RemotePort 53 -Protocol UDP -Action Allow

            # Kerberos Authentication
            Write-Host "Setting up Kerberos Authentication Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "Kerberos TCP Inbound 88" -Direction Inbound -LocalPort 88 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "Kerberos TCP Outbound 88" -Direction Outbound -RemotePort 88 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "Kerberos UDP Inbound 88" -Direction Inbound -LocalPort 88 -Protocol UDP -Action Allow
            New-NetFirewallRule -DisplayName "Kerberos UDP Outbound 88" -Direction Outbound -RemotePort 88 -Protocol UDP -Action Allow
            
            # SMB (SYSVOL / NETLOGON)
            Write-Host "Setting up SMB Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "SMB TCP Inbound 445" -Direction Inbound -LocalPort 445 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "SMB TCP Outbound 445" -Direction Outbound -RemotePort 445 -Protocol TCP -Action Allow
            
            # Time Sync
            Write-Host "Setting up Time Sync Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "W32Time UDP Inbound 123" -Direction Inbound -LocalPort 123 -Protocol UDP -Action Allow
            New-NetFirewallRule -DisplayName "W32Time UDP Outbound 123" -Direction Outbound -RemotePort 123 -Protocol UDP -Action Allow

            #--------------------------------------------------------------
            # ICMP (Diagnostics)
            #--------------------------------------------------------------
            Write-Host "Setting up ICMPV4 Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "ICMPv4 Inbound" -Protocol ICMPv4 -Direction Inbound -Action Allow
            New-NetFirewallRule -DisplayName "ICMPv4 Outbound" -Protocol ICMPv4 -Direction Outbound -Action Allow

            # Block mDNS via firewall
            New-NetFirewallRule -DisplayName "Block mDNS Inbound (UDP 5353)" -Direction Inbound -LocalPort 5353 -Protocol UDP -Action Block -ErrorAction SilentlyContinue | Out-Null
            New-NetFirewallRule -DisplayName "Block mDNS Outbound (UDP 5353)" -Direction Outbound -LocalPort 5353 -Protocol UDP -Action Block -ErrorAction SilentlyContinue | Out-Null

            # Kerberos Password Change
            Write-Host "Setting up Kerberos Password Change Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "Kerberos PW TCP Inbound 464" -Direction Inbound -LocalPort 464 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "Kerberos PW TCP Outbound 464" -Direction Outbound -RemotePort 464 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "Kerberos PW UDP Inbound 464" -Direction Inbound -LocalPort 464 -Protocol UDP -Action Allow
            New-NetFirewallRule -DisplayName "Kerberos PW UDP Outbound 464" -Direction Outbound -RemotePort 464 -Protocol UDP -Action Allow

            # LDAP
            Write-Host "Setting up LDAP Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "LDAP TCP Inbound 389" -Direction Inbound -LocalPort 389 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "LDAP TCP Outbound 389" -Direction Outbound -RemotePort 389 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "LDAP UDP Inbound 389" -Direction Inbound -LocalPort 389 -Protocol UDP -Action Allow
            New-NetFirewallRule -DisplayName "LDAP UDP Outbound 389" -Direction Outbound -RemotePort 389 -Protocol UDP -Action Allow

            # LDAPS (if enabled)
            Write-Host "Setting up LDAPS Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "LDAPS TCP Inbound 636" -Direction Inbound -LocalPort 636 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "LDAPS TCP Outbound 636" -Direction Outbound -RemotePort 636 -Protocol TCP -Action Allow

            # RPC Endpoint Mapper
            Write-Host "Setting up RPC Endpoint Mapper Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "RPC TCP Inbound 135" -Direction Inbound -LocalPort 135 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "RPC TCP Outbound 135" -Direction Outbound -RemotePort 135 -Protocol TCP -Action Allow

            # RPC Dynamic Range (RESTRICTED)
            Write-Host "Setting up RPC Dynamic Range Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "RPC Dynamic TCP 5000-5100 Inbound" -Direction Inbound -LocalPort 5000-5100 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "RPC Dynamic TCP 5000-5100 Outbound" -Direction Outbound -RemotePort 5000-5100 -Protocol TCP -Action Allow


        }
        function firwall-dns/ad {
        Write-Host "========================================"
        Write-Host "|      Starting Firewall dns/ad        |"
        Write-Host "========================================"
            #--------------------------------------------------------------
            # Backup existing firewall config
            #--------------------------------------------------------------
            $path = "C:\Backups\Firewall\Firewall_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').wfw"
            netsh advfirewall export $path

            #--------------------------------------------------------------
            # Disable NON-Microsoft rules only (safer than nuking everything)
            #--------------------------------------------------------------
            Get-NetFirewallRule |
            Where-Object { $_.Group -notlike "@%SystemRoot%*" } |
            Disable-NetFirewallRule

            #--------------------------------------------------------------
            #General Firewall Rules
            #--------------------------------------------------------------
            firewall-gen

        }
        function firewall-ftp{
        Write-Host "========================================"
        Write-Host "|       Starting Firewall FTP          |"
        Write-Host "========================================"
            #--------------------------------------------------------------
            # Backup existing firewall config
            #--------------------------------------------------------------
            $path = "C:\Backups\Firewall\Firewall_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').wfw"
            netsh advfirewall export $path

            #--------------------------------------------------------------
            # Disable NON-Microsoft rules only (safer than nuking everything)
            #--------------------------------------------------------------
            Get-NetFirewallRule |
            Where-Object { $_.Group -notlike "@%SystemRoot%*" } |
            Disable-NetFirewallRule

            #--------------------------------------------------------------
            #General Firewall Rules
            #--------------------------------------------------------------
            firewall-gen
        }
        function firewall-http{
        Write-Host "========================================"
        Write-Host "|       Starting Firewall HTTP         |"
        Write-Host "========================================"
            #--------------------------------------------------------------
            # Backup existing firewall config
            #--------------------------------------------------------------
            $path = "C:\Backups\Firewall\Firewall_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').wfw"
            netsh advfirewall export $path

            #--------------------------------------------------------------
            # Disable NON-Microsoft rules only (safer than nuking everything)
            #--------------------------------------------------------------
            Get-NetFirewallRule |
            Where-Object { $_.Group -notlike "@%SystemRoot%*" } |
            Disable-NetFirewallRule


            #--------------------------------------------------------------
            # HTTP 
            #--------------------------------------------------------------
            Write-Host "Setting up ICMPV4 Firewall Rules" -ForegroundColor Green
            New-NetFirewallRule -DisplayName "HTTP UDP Inbound 80" -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow
            New-NetFirewallRule -DisplayName "HTTP UDP Outbound 80" -Direction Outbound -RemotePort 80 -Protocol TCP -Action Allow
        
            #--------------------------------------------------------------
            #General Firewall Rules
            #--------------------------------------------------------------
            firewall-gen

        }

        #-------------------------------------------------------------- 
        # #Menu system 
        #-------------------------------------------------------------

        # Main menu for user interaction
        #-------------------------------------------------------------
        function Show-Menu-firewall {
            Write-Host "========================================"
            Write-Host "|              FIREWALL                |"
            Write-Host "========================================"
            Write-Host " "
            Write-Host " "
            Write-Host "`nSelect an option:"
            Write-Host "1. Base Firewall"
            Write-Host "2. Firewall for AD / DNS"
            Write-Host "3. Firewall for FTP"
            Write-Host "4. Firewall for HTTP"
            Write-Host "5. Exit"
        }

        # Main script loop
        #-------------------------------------------------------------
        $choice = ""
        while ($choice -ne "5") {
            Show-Menu-firewall
            $choice = Read-Host "Enter your choice"
            switch ($choice) {
                "1" {
                    firewall-base
                }
                "2" {
                    firwall-dns/ad
                }
               "3" {
                   firewall-ftp
                }
                "4" {
                    firewall-http
                }
                "5" {
                    Write-Host "Exiting script..."
        
               default {
                   Write-Host "Invalid choice, please try again."
                }
            }
        }
}
Read-Host "Press Enter to exit..."






    Write-Host "-----------------------------------------" -ForegroundColor Green
    Write-Host "|          Firewalls created            |" -ForegroundColor Green
    Write-Host "-----------------------------------------" -ForegroundColor Green
}# Choice three
Firewall-local