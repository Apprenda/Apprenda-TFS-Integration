# load the vststasksdk if not already available
if (-not (Get-Module -Name VstsTaskSdk))
{
    Import-Module .\VstsTaskSdk
}
$env:BUILD_SOURCESDIRECTORY =  "$dir"
# This is the inputs we would have provided in the task.
$env:INPUT_pathtozip = ".\TimeCard.zip"
$env:INPUT_alias = "testapp"
$env:INPUT_versionPrefix = "v"
$env:INPUT_stage = "Sandbox"
$env:INPUT_cloudurl = "https://apps.integrations.apprendalabs.com"
$env:INPUT_clouduser = "cdutra@apprenda.com"
$env:INPUT_cloudpw = "Apprenda2016!"
$env:INPUT_clouddevteam = "dutronlabs"
$env:INPUT_forcenewversion = $true

Invoke-VstsTaskScript -ScriptBlock ([scriptblock]::Create((resolve-path ..\apprendatasks\apprendaDeploy\sample.ps1))) -Verbose