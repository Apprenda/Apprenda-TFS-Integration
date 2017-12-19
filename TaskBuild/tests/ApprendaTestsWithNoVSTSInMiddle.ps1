# Include the common library in the checks
. "..\common\common.ps1"

$baseURI  = "https://apps.oracle.apprendalabs.com/"
$authJSON = '{"username":"mmichael@apprenda.com","password":"password"}'
$global:ApprendaSessiontoken = [string]::Empty

function GetSessionToken($body, $authURI)
{    
    $uri = $baseURI + $authURI
    try 
    {
        $jsonOutput = Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json" -Body $body     
        $global:ApprendaSessiontoken = $jsonOutput.apprendaSessionToken
        Write-Host "The Apprenda session token is " $global:ApprendaSessiontoken -ForegroundColor DarkYellow
    }
    catch [System.Exception]
    {
        $exceptionMessage = $_.Exception.ToString()
        Write-Error "Caught exception $exceptionMessage during execution of GetSessionToken for URI $uri. Exiting..."
        exit 23
    }  
}

function InvokeRESTMethod($body, $requestURI, $methodType)
{
    $Headers = @{}
    $Headers["ApprendaSessionToken"] = $global:ApprendaSessiontoken

    if ($requestURI -notlike "https://*")
    {
        $uri = $baseURI + $requestURI
    }
    else
    {
        $uri = $requestURI
    }

    $response = [string]::Empty
    try
    {
        if ([string]::IsNullOrEmpty($body))
        {
            $response = Invoke-WebRequest -Uri $uri -Method $methodType -ContentType "application/json" -Headers $Headers
        }
        else
        {
            $response = Invoke-WebRequest -Uri $uri -Method $methodType -ContentType "application/json" -Body $body -Headers $Headers 
        }
    
        # Apprenda REST API Response Codes: http://docs.apprenda.com/restapi/appmanagement/v1/response_codes
        if ($response.StatusCode -lt 400)
        {
            Write-Host "Method $requestURI was successful with Status Code" $response.StatusCode " and Description " $response.StatusDescription
        }
        else
        {
            Write-Error "Method $requestURI failed with Status Code" $response.StatusCode " and Description " $response.StatusDescription 
        }
        
        if (($response.Content | convertfrom-json).Messages -is [Array])
        {
            foreach ($message in ($response.Content | convertfrom-json).Messages)
            {
                if (![string]::IsNullOrEmpty($message))
                {
                    Write-Warning $message 
                }
            }
        }

        return $response
    }
    catch [System.Exception]
    {
        $exceptionMessage = $_.Exception.ToString()
        Write-Error "Caught exception $exceptionMessage during execution of URI $requestURI."
    }  
}

# TFS specific settings
$global:versionsURI = "$($baseURI)developer/api/v1/versions"

# Initiate an Apprenda session and get the Auth Token
GetSessionToken $authJSON "authentication/api/v1/sessions/developer"

# Create a new application in Apprenda
$applicationUniqueName = "timecardm27"
#$newAppJSON = "{""Name"":""$applicationUniqueName"",""Alias"":""$applicationUniqueName"",""Description"":""An app created from PowerShell over REST""}"
#$response = InvokeRESTMethod $newAppJSON "developer/api/v1/apps" "POST"

# Upload an archive for the application I created above
#$archiveURL = "http://docs.apprenda.com/sites/default/files/TimeCard.zip"
#$response = InvokeRESTMethod "" "developer/api/v1/versions/$applicationUniqueName/v2?action=setArchive&archiveUri=$archiveURL" "POST"

$result = PromoteVersion $applicationUniqueName "v3" "Published" $true