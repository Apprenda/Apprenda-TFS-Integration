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
$global:TargetVersion=""
$global:DemoteFirst=$false

try {
    Write-Verbose "Gathering VSO variables."
    $pathtozip = Get-VstsInput -Name pathtozip -Require
    $alias = Get-VstsInput -Name alias -Require
    $name = Get-VstsInput -Name name
    if ($name -eq $null){
        $name = $alias
    }
    $versionPrefix = Get-VstsInput -Name versionPrefix -Require
    $stage = Get-VstsInput -Name stage -Require
    $cloudurl = Get-VstsInput -Name cloudurl -Require
    $clouduser = Get-VstsInput -Name clouduser -Require
    $cloudpw = Get-VstsInput -Name cloudpw -Require
    $clouddevteam = Get-VstsInput -Name clouddevteam -Require
    $forcenewversion = Get-VstsInput -Name forcenewversion -Require

    Write-Verbose "****************************************************"
    Write-Verbose "*         Input Check                               "
    Write-Verbose "* pathtozip= $pathtozip"
    Write-Verbose "* alias= $alias"
    Write-Verbose "* name= $name"
    Write-Verbose "* versionPrefix= $versionPrefix"
    Write-Verbose "* stage= $stage"
    Write-Verbose "* cloudurl= $cloudurl"
    Write-Verbose "* clouduser= $clouduser"
    Write-Verbose "* cloudpw= $cloudpw"
    Write-Verbose "* clouddevteam= $clouddevteam"
    Write-Verbose "****************************************************"
    Write-Verbose "Starting deployment to Apprenda environment: $cloudurl"
    Write-Verbose "Validating archive file."

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
        $appexists = $false
        $apps = GetApplications
        foreach ($app in $apps)
        {
            if ($app.alias -eq $alias)
            {
                Write-Host "Application exists, will run version detection engine and create new version, if necessary."
                $appexists = $true
                break
            }
        }
        $targetVersion = ""
        # Use Case - the application doesn't exist, create it.
        if(-not $appexists)
        {
            Write-Host "Application does not exist, creating $alias."
            CreateNewApplication $alias $name ""
            # when an application is created, v1 is automatically generated. we need to force the creation of a new version if the prefix is anything other than "v"
            if (-not $versionPrefix -eq "v")
            {
                CreateNewVersion $alias $versionPrefix+"1"
            }
            $global:targetVersion = $versionPrefix + "1"
            $response = UploadVersion $alias $global:targetVersion $fullpath
        }
        else
        # Use Case - Application does exist, figure out what version we require to patch, creating the new version if necessary
        {
            Write-Host "Application exists, running version checker."
            GetTargetVersion $alias $versionPrefix $forcenewversion
            if($global:DemoteFirst)
            {
                DemoteVersion $alias $global:targetVersion
            }
            $response = UploadVersion $alias $global:targetVersion $fullpath
        }
        # Lastly, promote to the target stage
        if($stage -eq "Sandbox" -or $stage -eq "Published")
        {
            PromoteVersion $alias $global:targetVersion $stage
        }
    }
    else
    {
        Write-Error "Cannot authenticate, error occured during login process."
        exit 1
    }
}

finally {
    Trace-VstsLeavingInvocation $MyInvocation
}