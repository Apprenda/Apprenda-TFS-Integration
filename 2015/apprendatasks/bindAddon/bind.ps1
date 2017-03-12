param(
  [string] $addonalias,
  [string] $instancealias,
  [string] $targetfile,
  [string] $appsettingskey,
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
$AddonsEndpointURI = '/developer/api/v1/addons'
$global:addonsURI = [string]::Empty
$global:authURI = [string]::Empty
$global:ApprendaSessiontoken = [string]::Empty
$global:Headers = @{}
$global:TargetVersion=""
$global:DemoteFirst=$false

try {
    Write-Verbose "Gathering VSO variables."
    $addonalias = Get-VstsInput -Name addonalias -Require
    $instancealias = Get-VstsInput -Name instancealias -Require
    $targetfile = Get-VstsInput -Name targetfile -Require
    $appsettingskey = Get-VstsInput -Name appsettingskey -Require
    $cloudurl = Get-VstsInput -Name cloudurl -Require
    $clouduser = Get-VstsInput -Name clouduser -Require
    $cloudpw = Get-VstsInput -Name cloudpw -Require
    $clouddevteam = Get-VstsInput -Name clouddevteam -Require

    Write-Verbose "****************************************************"
    Write-Verbose "*         Input Check                               "
    Write-Verbose "* pathtozip= $pathtozip"
    Write-Verbose "* alias= $alias"
    Write-Verbose "* versionPrefix= $versionPrefix"
    Write-Verbose "* stage= $stage"
    Write-Verbose "* cloudurl= $cloudurl"
    Write-Verbose "* clouduser= $clouduser"
    Write-Verbose "* cloudpw= <redacted>"
    Write-Verbose "* clouddevteam= $clouddevteam"
    Write-Verbose "****************************************************"

    Write-Verbose "Step 1: Finding target files in package."

    # If the target file is the default value, then we are looking for
    # two files in this package
    if $targetfile -eq ""
    $files = Get-ChildItem -Path $MyInvocation.MyCommand.Path -Filter *.config -Include app.*,web.* -Recurse

    # Test to make sure zip file is available.
    $fullpath = Resolve-Path $pathtozip
    Write-Verbose $fullpath
    if(-Not (Test-Path ($fullpath)))
    {
        Write-Error "Cannot find the archive file to deploy to ACP"
        exit 1
    }

    # Ensure the application alias is less than or equal to 20 characters
    if($alias.length -gt 20)
    {
        Write-Error "The application alias cannot be more than 20 characters"
        exit 1                
    }

    # Sanitize URLs and Authenticate
    FormatURL $AddonsEndpointURI $cloudurl ([ref]$global:addonsURI)
    Write-Verbose "global:addonsuri: $global:addonsURI"
    FormatURL $AuthenticationEndpointURI $cloudurl ([ref]$global:authURI)
    Write-Verbose "global:authuri: $global:authURI"
    $devAuthJSON = FormatAuthBody $clouduser $cloudpw $clouddevteam
    Write-Verbose "devAuthJson: $devAuthJSON"
    GetSessionToken $devAuthJSON

    # Get addon instance information
    if (-Not ([string]::IsNullOrEmpty($global:ApprendaSessiontoken)))
    {
        $token = [string]::empty
        $global:addonalias = $addonalias
        $global:addoninstancealias = $instancealias
        $global:Headers["ApprendaSessionToken"] = $global:ApprendaSessiontoken
        # this will run in common.ps1
        $instance = GetAddonInstances
        if($instance -eq $null)
        {
            Write-Error "Could not retrieve the addon instance information you requested."
            exit 1
        }
        else
        {
            # we confirm availability of the addon instance, so let's build the token
            $token = "`$`#ADDON-$instancealias`#`$"
        }


    }
    else
    {
        Write-Error "Cannot authenticate, error occured during login process."
        exit -1
    }
}

finally {
    Trace-VstsLeavingInvocation $MyInvocation
}