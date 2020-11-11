
<#
    .SYNOPSIS
    Displays various attributes of device(s) within Carbon Black.
    
    .NOTES
    Enter your API Secret Key, API ID, Org Key, and Environment to the corresponding variables.
    
    .PARAMETER ComputerName
    The device name or sensor ID of the device being targeted.
    
    .PARAMETER Path
    The filepath containing a list of devices being targeted.

    .EXAMPLE
    Get-CbDeviceStatus -ComputerName "tims-pc"

    .EXAMPLE
    Get-CbDeviceStatus -Path "C:\Users\Tim\Desktop\computer_list.txt"
#>

function Get-CbDeviceStatus {
    param (
        [Parameter(ParameterSetName = "ComputerName")]
        [string]$ComputerName,

        [Parameter(ParameterSetName = "Path")]
        [System.IO.FileInfo]$Path
    )
    $apiSecret = "API SECRET KEY HERE"
    $apiID = "API ID HERE"
    $apiKey = "$apiSecret/$apiID"
    $orgKey = "ORG KEY HERE"
    $environment = "defense-prod05"
    $baseUrl = "https://$environment.conferdeploy.net/appservices/v6/orgs/$orgKey/"
    $headers = @{
        'X-Auth-Token'= "$apiKey"
        'Content-Type' = 'application/json'
    }
    
    if ($ComputerName) {
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

            $sensorID = $searchResults.results.id[$selection]

            $searchBody = @{
                "query" = $sensorID
            } | ConvertTo-Json

            $searchResults = (Invoke-RestMethod -Uri ($baseUrl + "devices/_search") -Method Post -Headers $headers -Body $searchBody -ContentType "application/json")
            Write-Output $searchResults.results | Select-Object -Property name, id, login_user_name, status, sensor_version, os_version, uninstall_code, last_contact_time
        } else {
            $searchBody = @{
                "query" = $ComputerName
            } | ConvertTo-Json
            
            try {
                $searchResults = (Invoke-RestMethod -Uri ($baseUrl + "devices/_search") -Method Post -Headers $headers -Body $searchBody -ContentType "application/json")    
                Write-Output $searchResults.results | Select-Object -Property name, id, login_user_name, status, sensor_version, os_version, uninstall_code, last_contact_time    
            }
            catch {
                throw $_.Exception
            }
        }
    }

    if ($Path) {
        
        try {
            $devices = Get-Content -Path $Path
        }
        catch {
            $_.Exception
        }

        $devicesInfo = @()
        $nonexistentDevices = @{}
        foreach ($device in $devices) {
            $searchBody = @{
                "query" = $device.psobject.BaseObject
            } | ConvertTo-Json

            try {
                $searchResults = (Invoke-RestMethod -Uri ($baseUrl + "devices/_search") -Method Post -Headers $headers -Body $searchBody -ContentType "application/json")
                if ($searchResults.num_found -eq '0') {
                    $nonexistentDevices.Add($device,"NOT_FOUND")
                }
                $attributes = $searchResults.results | Select-Object -Property name, id, login_user_name, status, sensor_version, os_version, uninstall_code, last_contact_time    
                $devicesInfo += $attributes
            }
            catch {
                throw $_.Exception
                continue
            }
        }
        $devicesInfo | Format-Table
        $nonexistentDevices | Format-Table
    }
}