param(
    [string] $SolutionPath,
    [string] $OutputPath,
    [string] $Build = "false",
    [string] $Configuration = "Release",
    [string] $PrivateUI,
    [string] $PublicUI,
    [string] $PrivateRoot,
    [string] $PublicRoot,
    [string] $WcfService,
    [string] $WindowsService,
    [string] $additionalParams
)

Trace-VstsEnteringInvocation $MyInvocation Verbose
Write-Verbose "Collecting VSO Variables."
$SolutionPath = Get-VstsInput -Name SolutionPath -Require
$OutputPath = Get-VstsInput -Name OutputPath -Require
$Build = Get-VstsInput -Name Build -Require
$Configuration = Get-VstsInput -Name Configuration -Require
$PrivateUI = Get-VstsInput -Name PrivateUI
$PublicUI = Get-VstsInput -Name PublicUI
$PrivateRoot = Get-VstsInput -Name PrivateRoot
$PublicRoot = Get-VstsInput -Name PublicRoot
$WcfService = Get-VstsInput -Name WcfService
$WindowsService = Get-VstsInput -Name WindowsService


$cmd = @"
& "$PSScriptRoot\acs\acs.exe" NewPackage -Sln "$SolutionPath" -O "$OutputPath"
"@

if([System.Convert]::ToBoolean($Build)) {
    $cmd += " -b"
}

if(-not [System.String]::IsNullOrEmpty($PrivateUI))
{

    $cmd += @"
 -I "$PrivateUI"
"@
}

if(-not [System.String]::IsNullOrEmpty($PrivateRoot))
{
    $cmd += @"
 -PrivateRoot "$PrivateRoot"
"@
}


if(-not [System.String]::IsNullOrEmpty($WcfService))
{
	$cmd += @"
 -S "$WcfService"
"@
}

if(-not [System.String]::IsNullOrEmpty($WindowsService))
{
    $cmd += @"
 -WS "$WindowsService"
"@
}

Write-Host "Executing Command: $cmd"

iex $cmd

Trace-VstsLeavingInvocation $MyInvocation