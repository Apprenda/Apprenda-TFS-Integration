
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
function GetTargetVersion([PSObject[]] $versions, $alias, $versionPrefix, $forceNewVersion, $versionName)
{
    write-verbose "Versions: $($versions | convertto-json)"
    write-verbose "Alias: $alias"
    write-verbose "Prefix: $versionPrefix"
    write-verbose "forceNewVersion: $forceNewVersion"
    write-verbose "versionName: $versionName"

    $versionInfo = new-object -typename psobject -property @{
        Alias = "v1"
        CurrentStage = "Definition"
        createApplication = ($versions.length -eq 0)
        createVersion = $false        
        demoteThenPromote = $false
    }

    write-verbose "Entering GetTargetVersion with $($versions.length) versions to consider"
    if ($versions.length -le 1)
    {
        if ($versions.length -eq 0){
            return $versionInfo
        }
         if ($versions.length -gt 0 -and $versions[0].stage -ne "Published")
        {
            $versionInfo.CurrentStage = $versions[0].stage
            return $versionInfo
        }
    }

    $pattern = "$versionPrefix[0-9]*"
    $matchingVersions = ($versions  | Where-Object { $_.alias -match $pattern })
    write-verbose "Matching: $(convertto-json $matchingVersions )"

    # If no matching versions, create $versionPrefix + 1 (ie. v1)
    if($matchingVersions.length -eq 0 -and ($versions | where-object { $_.stage -eq "Published"}).Lenth -gt 0)
    {
        write-verbose "No versions with versionprefix [$versionPrefix] and already have at least one published version."
        $versionInfo.Alias = $versionPrefix + "1"
        $versionInfo.CurrentStage = "Definition"
        $versionInfo.createVersion = $true
    }
    # Otherwise grab the highest version number and stage.
    else
    {

        $enrichedVersions = foreach($version in $matchingVersions) {
            write-verbose "Enhancing $(convertto-json $version)"
            new-object -typename psobject -property @{
                Alias= $version.alias
                Number = [int] $version.alias.substring($versionPrefix.length)
                Stage = $version.stage
                State = $version.state            
            }
        }
        write-verbose "Enriched: $(convertto-json $enrichedVersions)"
        $maxVersion = $enrichedVersions | sort-object -property Number -Descending | select-object -First 1 

        $versionInfo.CurrentStage = $maxVersion.stage

        switch ($maxVersion.stage)
        {
            "Definition" {
                if ($forceNewVersion) { 
                    $versionInfo.createVersion = $true
                    $versioninfo.Alias = "$versionPrefix$($maxVersion.Number+1)"
                } else {
                    $versionInfo.Alias = $maxVersion.Alias
                }
            }
            "Sandbox" {
                if ($forceNewVersion) { 
                    $versionInfo.createVersion = $true
                    $versioninfo.Alias = "$versionPrefix$($maxVersion.Number+1)"
                } else {
                    $versionInfo.Alias = $maxVersion.Alias 
                    $versionInfo.demoteThenPromote = $true
                }
            }
            "Published" { 
                $versionInfo.Alias = "$versionPrefix$($maxVersion.Number+1)"
                $versionInfo.createVersion = $true
            }
            "Archived" {                
                $versionInfo.Alias = "$versionPrefix$($maxVersion.Number+1)"
                $versionInfo.createVersion = $true
             }
            default{ 
                $versionInfo.Alias = "$versionPrefix$($maxVersion.Number+1)"
                $versionInfo.createVersion = $true
            }
        }
        return $versioninfo
    }
}

