param(
  [string] $alias,
  [string] $versionAlias,
  [string] $stage,
  [string] $cloudurl,
  [string] $clouduser,
  [string] $cloudpw,
  [string] $clouddevteam
)

Trace-VstsEnteringInvocation $MyInvocation Verbose

# Dot Source the Common Functions Used across all tasks.
. "$PSScriptRoot\common.ps1"
#Constants 
$AuthenticationEndpointURI = "/authentication/api/v1/sessions/developer/"
$AppsEndpointURI = '/developer/api/v1/apps'
$VersionsEndpointURI = '/developer/api/v1/versions'
$global:appsURI = [string]::Empty
$global:versionsURI = [string]::Empty
$global:authURI = [string]::Empty
$global:ApprendaSessiontoken = [string]::Empty
$global:Headers = @{}
$ignoreCertificateValidation = $false

try {
    Write-Verbose "Gathering VSO variables."
    $alias = Get-VstsInput -Name alias -Require
    $versionAlias = Get-VstsInput -Name versionalias

    if ($versionAlias.Length -eq 0) 
    {
        $versionalias = Get-VstsTaskVariable -Name NewVersion -Require
    }
    $stage = Get-VstsInput -name stage -Require
    $cloudurl = Get-VstsInput -Name cloudurl -Require
    $clouduser = Get-VstsInput -Name clouduser -Require
    $cloudpw = Get-VstsInput -Name cloudpw -Require
    $clouddevteam = Get-VstsInput -Name clouddevteam -Require
    $retainScalingSettings = Get-VstsInput -Name retainScalingSettings
    $ignoreCertificateValidation = Get-VsTsInput -name ignoreCertificateValidation

    Write-Verbose "****************************************************"
    Write-Verbose "*         Input Check                               "
    Write-Verbose "* alias= $alias"
    Write-Verbose "* versionAlias = $versionalias"
    Write-Verbose "* stage = $stage"
    Write-Verbose "* cloudurl= $cloudurl"
    Write-Verbose "* clouduser= $clouduser"
    Write-Verbose "* cloudpw= $cloudpw"
    Write-Verbose "* clouddevteam= $clouddevteam"
    Write-Verbose "* ignoreCertificateValidation= $ignoreCertificateValidation"
    Write-Verbose "* retainScalingSettings = $retainScalingSettings"
    Write-Verbose "****************************************************"
if ($ignoreCertificateValidation){
    Write-Verbose "Disabling HTTPS certificate validation"
    EnableTrustAllCerts
}

    # Sanitize URLs and Authenticate
    FormatURL $AppsEndpointURI $cloudurl ([ref]$global:appsURI)
    Write-Verbose "global:appsuri: $global:appsURI"
    FormatURL $VersionsEndpointURI $cloudurl ([ref]$global:versionsURI)
    Write-Verbose "global:versionsuri: $global:versionsURI"
    FormatURL $AuthenticationEndpointURI $cloudurl ([ref]$global:authURI)
    Write-Verbose "global:authuri: $global:authURI"
    $devAuthJSON = FormatAuthBody $clouduser $cloudpw $clouddevteam
    Write-Verbose "devAuthJson: $devAuthJSON"
    GetSessionToken $devAuthJSON

    
    if (-Not ([string]::IsNullOrEmpty($global:ApprendaSessiontoken)))
    {
        $global:Headers["ApprendaSessionToken"] = $global:ApprendaSessiontoken
        $apps = GetApplications
        
        $appexists = $false
        $versionexists = $false
        $notInPublished = $true

        foreach ($app in $apps)
        {
            if ($app.alias -eq $alias)
            {
                Write-Host "Application exists, checking  target version alias."
                $appexists = $true
                break
            }
        }
        if($appexists)
        {
            $versions = GetVersions $alias
            foreach($version in $versions)
            {
                if($version.alias -eq $versionalias)
                {
                    $versionexists = $true
                    Write-Verbose "Located version alias, checking Stage to make sure it is not published."
                    if(($version.stage -eq "Sandbox") -or ($version.stage -eq "Definition"))
                    {
                        Write-Host "Requested application  version is not published."
                    }
                    else
                    {
                        Write-Error "The requested application version are unable to be promoted because it is already in the Published stage."
                        $notInPublished = $false
                    }
                    break
                }
            }
            if($versionexists -and $notInPublished)
            {
                Write-Verbose "Starting promotion of app $alias at version $versionalias."
                PromoteVersion $alias $versionalias $stage $retainScalingSettings
                Write-Host "Successfully promoted app $alias at version $versionalias."
            }
            else
            {
                Write-Error "Found the application, but it did not meet the criteria for promotion. Please check your application metadata."
                exit 1
            }
        }
        else
        {
            Write-Error "The requested application for promotion does not exist under this current developer team."
            exit 1
        }
    }
    else
    {
        Write-Error "Cannot authenticate, error occured during login process."
        exit -1
    }

} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
