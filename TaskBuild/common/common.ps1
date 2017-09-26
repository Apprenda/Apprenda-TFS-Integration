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
        #Write-Host "The Apprenda session token is: '$global:ApprendaSessiontoken'"
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
        if ($name.Length -eq 0){
            $name = $alias;
        }
        
        $appsBody = "{`"Name`":`"$($name)`",`"Alias`":`"$($alias)`",`"Description`":`"$($description)`"}"
        Invoke-WebRpc $global:appsURI $appsBody
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

function GetResponseStreamAsJson($response)
{
    $stream = $null;
    if ($response -is [System.Net.HttpWebResponse]){
        $stream = $response.GetResponseStream()
        $reader = new-object System.IO.StreamReader($stream)
        if ($reader.BaseStream.CanSeek)
        {
            $reader.BaseStream.Position = 0;
        }
        $responseString = $reader.ReadToEnd();
        return $responseString | convertfrom-json    
    }
    if ($response -is [Microsoft.PowerShell.Commands.BasicHtmlWebResponseObject])
    {
        return $response.Content | convertfrom-json
    }
}

function CreateNewVersion($appAlias, $versionAlias, $versionName)
{
    try
    {
        $versionBody = "{`"Name`":`"$($versionName)`",`"Alias`":`"$($versionAlias)`",`"Description`":`"$($versionName)`"}"
        $uri = $global:versionsURI + '/' + $appAlias
        Invoke-WebRequest -Uri $uri -Method POST -ContentType "application/json" -Headers $global:Headers -Body $versionBody -TimeoutSec 1200 -UseBasicParsing
        Write-Host "   Created Version '$($versionName)' with alias '$($versionAlias))' for '$($appAlias)'."
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
    write-host Returned $response.StatusCode
    if($($response.StatusCode) -eq 200 )
    {
        Write-Host "   Archive for '$($alias)' has been uploaded."
        write-verbose (GetResponseStreamAsJson $response)
    }
    else
    {
        $Host.UI.WriteErrorLine("   Error Uploading Binaries for Application '$($appInfo.alias)'")
        $Host.UI.WriteErrorLine($($responseObject.message))     
        return $false
    }
}

function printReportCard($reportCard)
{
    
	$report = [System.Collections.ArrayList]@()
    foreach ($section in $reportCard.sections)
    {
		$sectioned = $false
        foreach ($message in $section.messages)
        {
            if ($message.severity -ne "Error") 
            {
                write-verbose -message "$($section.title)::$($message.message)"
                continue
            }
            Write-Error -Message "$($section.title)::$($message.message)"
        }
    }
}

function Invoke-WebRpc($uri, $content){
    write-verbose "Invoking $uri with $content"
    $request = [System.Net.HttpWebRequest]::CreateHttp($uri)
    $request.Method = "POST"
     $request.Headers.Add("ApprendaSessionToken", $global:ApprendaSessiontoken)
     if ($content -ne $null){
         $body = [byte[]][char[]]$content
         $request.ContentLength = $body.Length
         $request.ContentType = "application/json"
         $Stream = $request.GetRequestStream();
         $Stream.Write($body, 0, $body.Length);
     } else {
        $request.ContentLength = 0
     }
     try{
        $response = $request.GetResponse() 
        return GetResponseStreamAsJson $response
    } catch [System.Management.Automation.MethodInvocationException]{
        #the WebException is the inner exception here
        $webException = [System.Net.WebException]$_.Exception.InnerException
        
    if ($webException.Response -ne $null){
         $errorResponse = [System.Net.HttpWebResponse]$webException.Response
         return GetResponseStreamAsJson $errorResponse
        write-verbose "Response: $responseString"
         $response = $responseString  | convertfrom-json 
    }
    }

    return $response
}


function PromoteVersion($alias, $versionAlias, $stage, $retainScalingSettings)
{
    Write-verbose "Promoting application $alias version $versionAlias to stage $stage, retainScaleSettings = $retainScaleSettings"
    $promotionURI = $global:versionsURI + '/' + $alias + '/' + $versionAlias + "?action=promote&stage=" + $stage
    if ($retainScalingSettings -eq $true -and $versionAlias -ne "v1" ){
        $promotionUri = $promotionUri + "&useScalingSettingsFrom=Published"
        Write-Host "Using Scaling Settings from Published Version"
    }

    $response = Invoke-WebRpc($promotionURI)

    if($($response.success) -eq $true )
    {
        Write-Host "Application '$alias' has been Promoted to the '$stage' stage." -ForegroundColor Green
        return 0
    }
    else
    {
        PrintReportCard $response
        throw "Error Promoting Application '$alias' version $versionAlias to the $stage stage."
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
        $Host.UI.WriteErrorLine("Error Demoting Application '$alias' to the $stage stage.")
        $Host.UI.WriteErrorLine($($responseObject.message))     
    }
}


function EnableTrustAllCerts{
    add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}
function GetApplications()
{
    $response = Invoke-WebRequest -Uri $global:appsURI -Method GET -ContentType "application/json" -Headers $global:Headers -Timeoutsec 3600 -UseBasicParsing
    if($($response.StatusCode) -eq 200 )
    {
        # Write-Host $response
    }
    return $response | ConvertFrom-Json
}

function GetVersions($alias)
{
    $response = Invoke-WebRequest -Uri "$global:versionsURI/$alias" -Method GET -ContentType "application/json" -Headers $global:Headers -TimeoutSec 3600 -UseBasicParsing
    if($($response.StatusCode) -eq 200 )
    {
       # Write-Host $response
    }
    $versions  = $response | ConvertFrom-Json

    return $versions

}


