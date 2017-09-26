[cmdletbinding()]
Param()

$oneVersionPublished = convertfrom-json @'
[
{
"name": "Version 1",
"alias": "v1",
"description": null,
"stage": "Published",
"state": "Running",
"application": {
"href": "https://apps.apprenda.droptop/developer/api/v1/apps/Prefix"
},
"enableStickySessions": true,
"enableSessionReplication": false,
"enableSslEnforcement": false,
"loadBalancerUrlConfiguration": "Preserve",
"inMaintenance": false,
"href": "https://apps.apprenda.droptop/developer/api/v1/versions/Prefix/v1"
}
]
'@  

$oneVersionSandbox = convertfrom-json @'
[
{
"name": "Version 1",
"alias": "v1",
"description": null,
"stage": "Sandbox",
"state": "Running",
"application": {
"href": "https://apps.apprenda.droptop/developer/api/v1/apps/Prefix"
},
"enableStickySessions": true,
"enableSessionReplication": false,
"enableSslEnforcement": false,
"loadBalancerUrlConfiguration": "Preserve",
"inMaintenance": false,
"href": "https://apps.apprenda.droptop/developer/api/v1/versions/Prefix/v1"
}
]
'@  

$twoVersionsSandbox = convertfrom-json @'
[
{
"name": "Version 1",
"alias": "v1",
"description": null,
"stage": "Published",
"state": "Running",
"application": {
"href": "https://apps.apprenda.droptop/developer/api/v1/apps/Prefix"
},
"enableStickySessions": true,
"enableSessionReplication": false,
"enableSslEnforcement": false,
"loadBalancerUrlConfiguration": "Preserve",
"inMaintenance": false,
"href": "https://apps.apprenda.droptop/developer/api/v1/versions/Prefix/v1"
},
{
"name": "Version 2",
"alias": "v2",
"description": null,
"stage": "Sandbox",
"state": "Running",
"application": {
"href": "https://apps.apprenda.droptop/developer/api/v1/apps/Prefix"
},
"enableStickySessions": true,
"enableSessionReplication": false,
"enableSslEnforcement": false,
"loadBalancerUrlConfiguration": "Preserve",
"inMaintenance": false,
"href": "https://apps.apprenda.droptop/developer/api/v1/versions/Prefix/v1"
}

]
'@  

$twoVersionsPublished = convertfrom-json @'
[
{
"name": "Version 1",
"alias": "v1",
"description": null,
"stage": "Archived",
"state": "Stopped",
"application": {
"href": "https://apps.apprenda.droptop/developer/api/v1/apps/Prefix"
},
"enableStickySessions": true,
"enableSessionReplication": false,
"enableSslEnforcement": false,
"loadBalancerUrlConfiguration": "Preserve",
"inMaintenance": false,
"href": "https://apps.apprenda.droptop/developer/api/v1/versions/Prefix/v1"
},
{
"name": "Version 2",
"alias": "v2",
"description": null,
"stage": "Published",
"state": "Running",
"application": {
"href": "https://apps.apprenda.droptop/developer/api/v1/apps/Prefix"
},
"enableStickySessions": true,
"enableSessionReplication": false,
"enableSslEnforcement": false,
"loadBalancerUrlConfiguration": "Preserve",
"inMaintenance": false,
"href": "https://apps.apprenda.droptop/developer/api/v1/versions/Prefix/v1"
}
]
'@ 

function CreateNewVersion {}
function Set-VstsTaskVariable {}

$noVersions = '[]'

. "..\common\GetTargetVersion.ps1"

$result = GetTargetVersion ($noVersions) "TestApp" "v" $false "Initial V"
if ($result.Alias -ne "v1") {
     throw "noVersions: Should have chosen [v1], instead chose [$result]" 
}

$result = GetTargetVersion $noVersions "TestApp" "prefix"  $false "Initial V"
if ($result.Alias -ne "v1") {
     throw "noVersions prefix: Should have chosen [v1], instead chose [$result]" 
}


$result = GetTargetVersion $oneVersionSandbox "TestApp" "v" $false "Initial V"
if ($result.Alias -ne "v1") {
    throw "oneVersionSandbox: Should have chosen [v1], instead chose [$result]"
}


$result = GetTargetVersion $oneVersionSandbox "TestApp" "prefix" $false "Initial V"
if ($result.Alias -ne "v1") {
    throw "oneVersionSandbox prefix: Should have chosen [v1], instead chose [$result]."
}


$result = GetTargetVersion $oneVersionPublished "TestApp" "v" $false "Version 2"
if ($result.Alias -ne "v2") {
    throw "oneVersionPublished: should have chosen [v2], instead chose [$result]"
}

$result = GetTargetVersion $twoVersionsPublished "TestApp" "v" $false "Version 3"
if ($result.Alias -ne "v3") {
    throw "twoVersionsPublished: should have chosen [v3], instead chose [$result]"
}

$result = GetTargetVersion $twoVersionsSandbox "TestApp" "v" $false "Version 2"
if ($result.Alias -ne "v2") {
    throw "twoVersionsSandbox: should have chosen [v2], instead chose [$result]"
}

$result = GetTargetVersion $twoVersionsSandbox "TestApp" "prefix" $false "Version 2"
if ($result.Alias -ne "prefix1") {
    throw "twoVersionsSandbox prefix: should have chosen [prefix1], instead chose [$result]"
}

