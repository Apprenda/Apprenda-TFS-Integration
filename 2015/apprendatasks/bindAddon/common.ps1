function FormatURL($requestURI, $cloudurl, [ref]$responseURL)
{
    $PlatformURL = $cloudurl
    if($PlatformURL.ToLower().EndsWith("/")) { $PlatformURL = $PlatformURL.TrimEnd("/") }
    if($PlatformURL.ToLower().StartsWith("https://")) { $responseURL.value = $PlatformURL + $requestURI }
    elseif ($PlatformURL.ToLower().StartsWith("http://")) { $responseURL.value = $PlatformURL.Replace("http://", "https://") + $requestURI }
    else { $responseURL.value = "https://" + $PlatformURL + $requestURI }
}

function FormatAuthBody ($Username, $Password, $tenantAlias)
{
    $devAuthJSON = "{`"username`":`"$Username`",`"password`":`"$Password`",`"tenantAlias`":`"$tenantAlias`"}"
    return $devAuthJSON
}

function GetSessionToken($body)
{    
    try 
    {
        Write-Verbose "Starting authentication method to Apprenda Environment."
        $jsonOutput = Invoke-RestMethod -Uri $global:authURI -Method Post -ContentType "application/json" -Body $body -TimeoutSec 600
        $global:ApprendaSessiontoken = $jsonOutput.apprendaSessionToken
        Write-Host "The Apprenda session token is: '$global:ApprendaSessiontoken'"
    }
    catch [System.Exception]
    {
        $exceptionMessage = $_.Exception.ToString()
        Write-Error "Caught exception $exceptionMessage during execution of GetSessionToken for URI '$global:authURI'. Skipping Tenant..."
    }  
}


function CreateNewApplication($alias, $name, $description)
{     
    try
    {
        $appsBody = "{`"Name`":`"$($alias)`",`"Alias`":`"$($name)`",`"Description`":`"$($description)`"}"
        Invoke-WebRequest -Uri $global:appsURI -Method POST -ContentType "application/json" -Headers $global:Headers -Body $appsBody -TimeoutSec 1200 -UseBasicParsing
        Write-Host "   Created '$($alias)' application."
    }
    catch [System.Exception]
    {
        $exceptionMessage = $_.Exception.ToString()
        Write-Host "   Caught exception $exceptionMessage during execution of CreateApps for App '$($alias)'." -ForegroundColor Red -BackgroundColor Black
        Write-Host ""
        continue
    }     
}

function CreateNewVersion($alias)
{
    try
    {
        $versionBody = "{`"Name`":`"$($global:targetVersion)`",`"Alias`":`"$($global:targetVersion)`",`"Description`":`"`"}"
        $uri = $global:versionsURI + '/' + $alias
        Invoke-WebRequest -Uri $uri -Method POST -ContentType "application/json" -Headers $global:Headers -Body $versionBody -TimeoutSec 1200 -UseBasicParsing
        Write-Host "   Created Version '$($global:targetVersion)' for '$($alias)'."
    }
    catch [System.Exception]
    {
        $exceptionMessage = $_.Exception.ToString()
        Write-Host "   Caught exception $exceptionMessage during execution of CreateVersion for Version '$($verInfo.alias)' of '$($appInfo.alias)'." -ForegroundColor Red -BackgroundColor Black
        Write-Host ""
        continue
    }    
}

function UploadVersion($alias, $vAlias, $archive)
{
    $uploadURI = $global:versionsURI + '/' + $alias + '/' + $vAlias + "?action=setArchive"
    $response = Invoke-WebRequest -Uri $uploadURI -Method POST -InFile $archive -ContentType "multipart/form-data" -Headers $global:Headers -TimeoutSec 3600 -UseBasicParsing
    if($($response.StatusCode) -eq 200 )
    {
        Write-Host "   Archive for '$($alias)' has been uploaded."
    }
    else
    {
        $Host.UI.WriteErrorLine("   Error Uploading Binaries for Application '$($appInfo.alias)'")
        $Host.UI.WriteErrorLine($($responseObject.message))     
        return $false
    }
}

function PromoteVersion($alias, $versionAlias, $stage)
{
    $promotionURI = $global:versionsURI + '/' + $alias + '/' + $versionAlias + "?action=promote&stage=" + $stage
    $response = Invoke-WebRequest -Uri $promotionURI -Method POST -ContentType "application/json" -Headers $global:Headers -TimeoutSec 3600 -UseBasicParsing
        
    if($($response.StatusCode) -eq 200 )
    {
        Write-Host "Application '$alias' has been Promoted to the '$stage' stage." -ForegroundColor Green
    }
    else
    {
        $Host.UI.WriteErrorLine("Error Promoting Application '$alias' to the $stage stage.")
        $Host.UI.WriteErrorLine($($responseObject.message))     
    }
}

# We can only demote from Sandbox to Definition, this is primarily needed for user action or patching a version.
function DemoteVersion($alias, $versionAlias)
{
    $promotionURI = $global:versionsURI + '/' + $alias + '/' + $versionAlias + "?action=demote"
    $response = Invoke-WebRequest -Uri $promotionURI -Method POST -ContentType "application/json" -Headers $global:Headers -TimeoutSec 3600 -UseBasicParsing
        
    if($($response.StatusCode) -eq 200 )
    {
        Write-Host "Application '$alias' has been Demoted." -ForegroundColor Green
    }
    else
    {
        $Host.UI.WriteErrorLine("Error Promoting Application '$alias' to the $stage stage.")
        $Host.UI.WriteErrorLine($($responseObject.message))     
    }
}



function GetApplications()
{
    $response = Invoke-WebRequest -Uri $global:appsURI -Method GET -ContentType "application/json" -Headers $global:Headers -Timeoutsec 3600 -UseBasicParsing
    if($($response.StatusCode) -eq 200 )
    {
        Write-Host $response
    }
    return $response | ConvertFrom-Json
}

function GetVersions($alias)
{
    $response = Invoke-WebRequest -Uri "$global:versionsURI/$alias" -Method GET -ContentType "application/json" -Headers $global:Headers -TimeoutSec 3600 -UseBasicParsing
    if($($response.StatusCode) -eq 200 )
    {
        Write-Host $response
    }
    return $response | ConvertFrom-Json

}

# This routine does all of the major version analysis, dictated by the following rules:
# - IF a version does not exist that matches the prefix, a new one is created at 1.
# - IF a version does exist that matches the prefix: 
#     - If the highest version number is 1:
#          - If version stage is published, create <prefix>2 and patch to target stage
#          - If version stage is sandbox, definition, patch to target stage
#     - If the highest version number n such that n > 1:
#          - If version stage is published, create <prefix>n+1 and patch to target stage
#          - If version stage is sandbox | definition AND ForceNewVersion flag is $true, then create <prefix>n+1 and patch to target stage
#          - If version stage is sandbox | definition AND ForceNewVersion flas is $false, patch to target stage of version n.
function GetTargetVersion($alias, $versionPrefix, $forceNewVersion)
{
    $versions = GetVersions($alias)
    $matchingVersions = New-Object System.Collections.ArrayList
    # Step One - find all versions matching the prefix
    $pattern = "$versionPrefix[0-9]*"
    foreach($version in $versions)
    {
        if($version.alias -match $pattern)
        {
            $matchingVersions.Add(@{"valias"=$version.alias; "vstage"=$version.stage; "vh"=[int]$version.alias.Substring($versionPrefix.Length)})
        }
    }
    # If no matching versions, create $versionPrefix + 1 (ie. v1)
    if($matchingVersions.length -eq 0)
    {
        $global:targetVersion = $versionPrefix + "1"
        CreateNewVersion $alias
    }
    # Otherwise grab the highest version number and stage.
    else
    {
        $highestVersionCount = 0
        $highestVersionStage = ""
        # vh here will have the highest version number available
        # we also will grab the stage of the highest version while we're here.
        foreach($matchingVersion in $matchingVersions)
        {
            Write-Verbose "Version $matchingVersion.vh, $matchingVersion.vstage"
            # since 1>0, this will always hit. 
            if ($matchingVersion.vh -gt $highestVersionCount)
            {
                $highestVersionCount = $matchingVersion.vh
                $highestVersionStage = $matchingVersion.vstage
            }
            Write-Verbose "After iteration, highest version is : $highestversionCount with stage: $highestVersionStage"
        }
        # 1.10.17 - version 0.0.18
        # as a safeguard - we may have a version with a new prefix while other versions exist. so if we are still zero, use v1
        if ($highestVersionCount -eq 0)
        {
            $highestVersionCount = 1
        }
        # issue 1 - this functionality needs to be split out a bit
        if (($highestVersionCount -gt 1 -and (($highestVersionStage -eq "Published") -or ($forceNewVersion -eq $true))) -or
        ($highestVersionCount -eq 1 -and $highestVersionStage -eq "Published"))
        {
            $highestVersionCount = $highestVersionCount +  1
            $global:targetVersion = $versionPrefix + $highestVersionCount 
            CreateNewVersion $alias
        }
        else
        {
            if($highestVersionStage -eq "Sandbox")
            {
                # we have to demote first before we can patch. ugh.
                $global:DemoteFirst=$true
            }
            $global:targetVersion = $versionPrefix + $highestVersionCount
        }
        Write-Verbose "Global Target Version: $global:targetVersion"
    }
}