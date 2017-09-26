param(
  [string] $pathtozip,
  [string] $alias,
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
$global:DemoteFirst=$false
ignoreCertificateValidation = $false

try {
    Write-Verbose "Gathering VSO variables."
    $pathtozip = Get-VstsInput -Name pathtozip -Require
    $alias = Get-VstsInput -Name alias -Require
    $versionalias = Get-VstsInput -Name versionalias -Require
    $instanceCount = Get-VstsInput -Name instanceCount -Require
    $scaleComponent = Get-VstsInput -Name scalecomponent -Require
    # not required unless $scaleComponent -eq $true
    $componentAlias = Get-VstsInput -Name componentAlias 
    $cloudurl = Get-VstsInput -Name cloudurl -Require
    $clouduser = Get-VstsInput -Name clouduser -Require
    $cloudpw = Get-VstsInput -Name cloudpw -Require
    $clouddevteam = Get-VstsInput -Name clouddevteam -Require
    $forcenewversion = Get-VstsInput -Name forcenewversion -Require
    $ignoreCertificateValidation = Get-VsTsInput -name ignoreCertificateValidation

    Write-Verbose "****************************************************"
    Write-Verbose "*         Input Check                               "
    Write-Verbose "* versionAlias = $versionalias"
    Write-Verbose "* alias= $alias"
    Write-Verbose "* cloudurl= $cloudurl"
    Write-Verbose "* clouduser= $clouduser"
    Write-Verbose "* cloudpw= $cloudpw"
    Write-Verbose "* clouddevteam= $clouddevteam"
    Write-Verbose "* stage= $stage"
    Write-Verbose "* ignoreCertificateValidation = $ignoreCertificateValidation"
    Write-Verbose "****************************************************"


    # Sanitize URLs and Authenticate
    FormatURL $AppsEndpointURI $cloudurl ([ref]$global:appsURI)
    Write-Verbose "global:appsuri: $global:appsURI"
    FormatURL $VersionsEndpointURI $cloudurl ([ref]$global:versionsURI)
    Write-Verbose "global:versionsuri: $global:versionsURI"
    FormatURL $AuthenticationEndpointURI $cloudurl ([ref]$global:authURI)
    Write-Verbose "global:authuri: $global:authURI"
    $devAuthJSON = FormatAuthBody $clouduser $cloudpw $clouddevteam
    
    if ($ignoreCertificateValidation){
    Write-Verbose "Disabling HTTPS certificate validation"
    EnableTrustAllCerts
}
    Write-Verbose "devAuthJson: $devAuthJSON"
    GetSessionToken $devAuthJSON

    
    if (-Not ([string]::IsNullOrEmpty($global:ApprendaSessiontoken)))
    {
        $global:Headers["ApprendaSessionToken"] = $global:ApprendaSessiontoken
    }
    else
    {
        Write-Error "Cannot authenticate, error occured during login process."
        exit -1
    }


} finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
