
<#
    .SYNOPSIS
    Deregisters device within Carbon Black console. Intended to be run manually, logic is built in for user confirmation and multiple devices resulting from a search.
    
    Enter your API Secret Key, API ID, and Org Key on lines 19, 20, and 22, respectively.

    .PARAMETER ComputerName
    The device name or sensor ID of the device being targeted.
    
    .EXAMPLE
    Unregister-CbSensor -ComputerName "tims-pc"
#>

function Unregister-CbSensor {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ComputerName
    )
    $apiSecret = "API SECRET KEY HERE"
    $apiID = "API ID HERE"
    $apiKey = "$apiSecret/$apiID"
    $orgKey = "ORG KEY HERE"
    $baseUrl = "https://defense-prod05.conferdeploy.net/appservices/v6/orgs/$orgKey/"
    $headers = @{
        'X-Auth-Token'= "$apiKey"
        'Content-Type' = 'application/json'
    }

    $searchBody = @{
        "query" = $ComputerName
    } | ConvertTo-Json

    $searchResults = (Invoke-RestMethod -Uri ($baseUrl + "devices/_search") -Method Post -Headers $headers -Body $searchBody -ContentType "application/json")

    if ($searchResults.num_found -eq '0') {
        throw "ERROR: No sensor found for endpoint $ComputerName"
        exit
    } elseif ($searchResults.num_found -gt '1') {
        Write-Output "Found multiple ($($searchResults.num_found)) devices, please select the endpoint you wish to target: "

        #List each endpoint name from the response
        $endpointCount = ($searchResults.results.name).Count
        for ($i = 0; $i -lt $endpointCount; $i++) {
            Write-Output "$($i): $($searchResults.results.name[$i])"
        }

        #Prompt for user selection, input validation
        do {
            [ValidatePattern("[0-9]{1}")]$selection = Read-Host -Prompt "Select Endpoint"
        } while ((0..($endpointCount - 1)) -notcontains $selection)

        Write-Output "Selected device: $($searchResults.results.name[$selection])"
        $sensorID = $searchResults.results.id[$selection]
        Write-Output "Device sensor ID: $($sensorID)"

        #Uninstall payload
        $uninstallBody = @{
            "action_type" = "UNINSTALL_SENSOR"
            "device_id" = @($sensorID)
        } | ConvertTo-Json

        #User uninstall confirmation dialog
        $title   = "Uninstall Sensor"
        $msg     = "Are you sure you want to uninstall the sensor on $($searchResults.results.name[$selection])?"
        $options = '&Yes', '&No'
        $default = 1  # 0=Yes, 1=No
        do {
            $response = $Host.UI.PromptForChoice($title, $msg, $options, $default)
            if ($response -eq 0) {
                try {
                    $uninstallResults = (Invoke-WebRequest -Uri ($baseUrl + "device_actions") -Method Post -Headers $headers -Body $uninstallBody -ContentType "application/json")
                    if ($uninstallResults.StatusCode -eq "204") {
                        Write-Output "SUCCESS: Device $($searchResults.results.name) has been deregistered."
                    } else {
                        Write-Output "WARNING: Unexpected status code received"
                        Write-Output "Status Code: $($uninstallResults.StatusCode)"
                        Write-Output "Description: $($uninstallResults.StatusDescription)"
                    }
                }
                catch {
                    throw $_.Exception
                }
                break
            }
        } until ($response -eq 1)
        
    } else {
        Write-Output "Found device: $($searchResults.results.name)"
        $sensorID = $searchResults.results.id
        Write-Output "Device sensor ID: $($sensorID)"
        
        #Uninstall payload
        $uninstallBody = @{
            "action_type" = "UNINSTALL_SENSOR"
            "device_id" = @($sensorID)
        } | ConvertTo-Json

        #User uninstall confirmation dialog
        $title   = "Uninstall Sensor"
        $msg     = "Are you sure you want to uninstall the sensor on $($searchResults.results.name)?"
        $options = '&Yes', '&No'
        $default = 1  # 0=Yes, 1=No
        do {
            $response = $Host.UI.PromptForChoice($title, $msg, $options, $default)
            if ($response -eq 0) {
                try {
                    $uninstallResults = (Invoke-WebRequest -Uri ($baseUrl + "device_actions") -Method Post -Headers $headers -Body $uninstallBody -ContentType "application/json")
                    if ($uninstallResults.StatusCode -eq "204") {
                        Write-Output "SUCCESS: Device $($searchResults.results.name) has been deregistered."
                    } else {
                        Write-Output "WARNING: Unexpected status code received"
                        Write-Output "Status Code: $($uninstallResults.StatusCode)"
                        Write-Output "Description: $($uninstallResults.StatusDescription)"
                    }
                }
                catch {
                    throw $_.Exception
                }
                break            
            }
        } until ($response -eq 1)
    }
}