#--------------------------------------------------------------
#  Script-Enumeration Start | Downloads all are tools for comp
# Branched from All in one | Script for start of comp | Version | 1.26.5
# Made by Logan Schultz
#Version | 1.1
#--------------------------------------------------------------
$ProgressPreference = 'SilentlyContinue'
function Start-Enumeration {
    #TimeStamp
    $ts = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
Start-Transcript -Path "C:\Backups\Enumeration-log_$ts.txt"
    #--------------------------------------------------------------
    # Enumeration
    #-------------------------------------------------------------- 
    Write-Host "========================================"
    Write-Host "|        System Enumeration            |"
    Write-Host "========================================"
    #Make file paths
    New-Item -ItemType Directory -Path "C:\Backups\Enumeration" -Force
    New-Item -ItemType Directory -Path "C:\Backups\Enumeration\Process" -Force
    New-Item -ItemType Directory -Path "C:\Backups\Enumeration\AdminUsers" -Force

    #TimeStamp
    $ts = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

    #Get all Process | Put in txt file
    #Get-Process > C:\Backups\Enumeration\Process\Processoutput_$ts.txt

    # Get all local users and their group memberships, then export to a text file
    Get-LocalUser | ForEach-Object {
        $user = $_.Name
        $groups = (Get-LocalGroup | Where-Object {
            (Get-LocalGroupMember $_.Name -ErrorAction SilentlyContinue | Where-Object Name -eq $user)
        }).Name -join ", "
    
        [PSCustomObject]@{
            UserName = $user
            Groups   = if ($groups) { $groups } else { "No Groups" }
        }
    } | Out-File -FilePath "C:\Backups\Enumeration\Process\LocalUsersAndGroups_$ts.txt" -Encoding UTF8
    
        try
        {
            Write-Output "========================================"
            Write-Output "|                                      |"
            Write-Output "|        Enumerated Machine Info       |"
            Write-Output "|                                      |"
            Write-Output "========================================"
    
            $h = Get-WmiObject -Class Win32_ComputerSystem
            $TotalRAM = ([Math]::Round(($h.TotalPhysicalMemory/1GB),0) )
            $mth = @{expression = {$_.DeviceLocator};Label="Slot"},`
                    @{expression = {$_.Speed};Label="Speed MHZ"},`
                    @{expression = {$_.Manufacturer};Label="Manufacturer"},`
                    @{expression = {($_.Capacity/1GB)};Label="Size GB"}
    
            Write-Output "Domain: $( $h.domain.toUpper())"
            Write-Output "HostName: $( $h.name.toUpper())"
            Write-Output "Total RAM: $TotalRAM GB";
            
            Get-CimInstance Win32_PhysicalMemory | ft $mth
    
            Write-Output "CPU Info"
            Write-Output "========================================"
    
    
           $cth = @{expression = {$_.DeviceID};Label="CPUID"},@{expression = {$_.Name};Label="Type"},@{expression = {$_.NumberofCores};Label="Cores"}
            Get-WmiObject -class win32_processor | ft $cth
    
            Write-Output "OS Info"
            Write-Output "========================================"
            Get-ComputerInfo -Property "Os*" 
    
            Write-Output "Installed Apps"
            Write-Output "========================================"
            If((Get-WmiObject Win32_OperatingSystem).OSArchitecture -notlike "*32-bit*") 
            {
                Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | where {$_.Displayname -and ($_.Displayname -notlike "*update for*")  } | sort Displayname | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate 
            }
            Else 
            {
                Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | where {$_.Displayname -and ($_.Displayname -notlike "*update for*")  } | sort Displayname | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate 
            }
        
            try
            {
                Write-Output "Roles and Features"
                Write-Output "========================================"
                Get-WindowsFeature | Where-Object {$_.InstallState -eq 'Installed'}
        
            }
            catch 
            {
                Write-Output "Not a Server"
            }
    
            Write-Output "Shares"
            Write-Output "========================================"
            Get-WmiObject -Class win32_share
        
    
            Write-Output "Listening Processes/Ports"
            Write-Output "========================================"
            netstat.exe -anb | Write-Output 
    
    
            Write-Output "DNS"
            Write-Output "========================================"
            $serveros = Get-ComputerInfo OsName
            if ($serveros -like "*2008 R2*") 
            {
                try 
                {
                        dnscmd /info
                }
                catch 
                {
                   Write-Output "Not a DNS server"
                }
            }
            else
            {
                try 
                {
                    #Output DNS Settings
                    get-dnsserver | out-file 
                }
                catch
                {
                    Write-Output "Not a DNS server"
            }
        }
    
        Write-Output "Scheduled Tasks"
        Write-Output "========================================"
        $hostname = hostname
        schtasks /query /s $hostname
    
        Write-Output "Local Users and Groups"
        Write-Output "========================================"
        Get-LocalUser
        Get-LocalGroup
    
        Write-Output "AD Users and Groups"
        Write-Output "========================================"
        if (Get-Module -ListAvailable -Name ActiveDirectory)
        {
            Get-ADUser -Filter 'enabled -eq $true' -Properties SamAccountname,DisplayName,memberof | % {
                New-Object PSObject -Property @{
                UserName = $_.DisplayName
                oSamAccountname= $_.SamAccountname
                Groups = ($_.memberof | Get-ADGroup | Select-Object -ExpandProperty Name) -join 
                ","}
                } | Select-Object oSamAccountname,UserName,Groups 
        }
        else 
        {
            Write-Output "AD is not installed"
        }
    
        Write-Host "[OK] " -ForegroundColor Green -NoNewLine
        Write-Host "Enumeration Completed!" -ForegroundColor Green
    }
    catch
    {
        Write-Host "[FAILED] " -ForegroundColor Red -NoNewLine
        Write-Host "An error occurred while enumerating, please try again" -ForegroundColor Red 
        }
Write-Host "-----------------------------------------" -ForegroundColor Green
Write-Host "|      System Enumeration Complete      |" -ForegroundColor Green
Write-Host "-----------------------------------------" -ForegroundColor Green
Stop-Transcript    
} # Choic Eight
Start-Enumeration