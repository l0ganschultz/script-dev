#--------------------------------------------------------------
# Script Open tools
# Branched from All in one | Script for start of comp | Version | 1.26.5
# Made by Logan Schultz
#Version | 1.0
#--------------------------------------------------------------
$ProgressPreference = 'SilentlyContinue'
function open-tools {
    #--------------------------------------------------------------
    #Open Tools
    #--------------------------------------------------------------
    function tool-sysinternals {
        # Start Sysinternals tools (Run as Admin)
        #--------------------------------------------------------------
        $extractPathSY = "C:\Sysinternals"
        Write-Host "Opening procexp" -ForegroundColor Green
        Start-Process -FilePath "$extractPathSY\procexp.exe" -Verb RunAs

        Write-Host "Opening tcpview" -ForegroundColor Green
        Start-Process -FilePath "$extractPathSY\tcpview.exe" -Verb RunAs

        Write-Host "Opening Autoruns" -ForegroundColor Green
        Start-Process -FilePath "$extractPathSY\Autoruns.exe" -Verb RunAs
    }
    function tool-local-security-policy{
        #Open local Security Policy
        #--------------------------------------------------------------

        Write-Host "Opening Local Security Policy" -ForegroundColor Green
        secpol.msc
    }
    function tool-computer-magement {
        #Open Computer Mangement
        #--------------------------------------------------------------
        Write-Host "Opening Computer Mangement" -ForegroundColor Green
        compmgmt.msc
    }
    function tool-event-viewer {
        #Open Event Viewer / Logs
        #--------------------------------------------------------------
        Write-Host "Opening Event Viewer" -ForegroundColor Green
        eventvwr.msc
    }
    function tool-everthing {
        #Open Everthing
        #--------------------------------------------------------------
        #$downloadPatheverthing = "C:\Users\$env:USERNAME\Downloads\Everything-1.4.1.1032.x86-Setup.exe"
        #Write-Host "Opening Everthing" -ForegroundColor Green
        #Start-Process "C:\Users\$env:USERNAME\Downloads\Everything-1.4.1.1032.x86-Setup.exe" -Verb RunAs
    }

Write-Host "========================================"
Write-Host "|          Opening Tools               |"
Write-Host "========================================"

#Call sub functions to open tools
tool-sysinternals
Write-Host "Sysinternals tools opened" -ForegroundColor DarkMagenta
tool-local-security-policy
Write-Host "Local Security Policy tools opened" -ForegroundColor DarkMagenta
tool-computer-magement
Write-Host "Computer Mangement opened" -ForegroundColor DarkMagenta
tool-event-viewer
Write-Host "Event Viewer opened" -ForegroundColor DarkMagenta
#tool-everthing #(broken at the moment)



Write-Host "-----------------------------------------" -ForegroundColor Green
Write-Host "|           All tools opened            |" -ForegroundColor Green
Write-Host "-----------------------------------------" -ForegroundColor Green
} # # Choice Siven
open-tools