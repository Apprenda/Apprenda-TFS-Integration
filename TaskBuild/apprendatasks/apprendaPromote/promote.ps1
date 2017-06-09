param(
  [string] $pathtozip,
  [string] $alias,
  [string] $name,
  [string] $description,
  [string] $versionPrefix,
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

try {
    Write-Verbose "Gathering VSO variables."
    $pathtozip = Get-VstsInput -Name pathtozip -Require
    $alias = Get-VstsInput -Name alias -Require
    $versionalias = Get-VstsInput -Name versionalias -Require
    $cloudurl = Get-VstsInput -Name cloudurl -Require
    $clouduser = Get-VstsInput -Name clouduser -Require
    $cloudpw = Get-VstsInput -Name cloudpw -Require
    $clouddevteam = Get-VstsInput -Name clouddevteam -Require
    $forcenewversion = Get-VstsInput -Name forcenewversion -Require
    Write-Verbose "****************************************************"
    Write-Verbose "*         Input Check                               "
    Write-Verbose "* versionAlias = $versionalias"
    Write-Verbose "* alias= $alias"
    Write-Verbose "* cloudurl= $cloudurl"
    Write-Verbose "* clouduser= $clouduser"
    Write-Verbose "* cloudpw= $cloudpw"
    Write-Verbose "* clouddevteam= $clouddevteam"
    Write-Verbose "****************************************************"

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
        
        # because we want to give a good experience, we're going to check to make sure
        # we can actually do the demotion first.
        $appexists = $false
        $versionexists = $false
        $isInSandbox = $false

        foreach ($app in $apps)
        {
            if ($app.alias -eq $alias)
            {
                Write-Host "Application exists, chceking target version alias."
                $appexists = $true
                break
            }
        }
        if($appexists)
        {
            $versions = GetVersions
            foreach($version in $versions)
            {
                if($version.alias -eq $versionalias)
                {
                    $versionexists = $true
                    Write-Host "Located version alias, checking Stage to make sure it is in Sandbox."
                    if($version.stage -eq "Sandbox")
                    {
                        Write-Host "Requested application and version are in Sandbox stage."
                        $isSandbox = $true
                    }
                    else
                    {
                        Write-Error "The requested application and version are unable to be demoted because they are not in Sandbox stage."
                    }
                    break
                }
            }
            if($versionexists -and $isSandbox)
            {
                Write-Verbose "Starting demotion of app $alias at version $versionalias."
                DemoteVersion $alias $versionalias
                Write-Host "Successfully demoted app $alias at version $versionalias."
            }
            else
            {
                Write-Error "We found the application, but it did not meet the criteria for demotion. Please check your application metadata."
                exit 1
            }
        }
        else
        {
            Write-Error "The requested application for demotion does not exist under this current developer team."
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
