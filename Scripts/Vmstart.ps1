$VmName = "vm-1,vm-2,vm-3,vm-4,vm-5,vm-6,vm-7,vm-8,vm-9,vm-10" 
$ResourceGroupName = "VMautomation-rg"                               
$VmAction = "Startup"    
$LogicAppURL = "https://prod-23.eastus2.logic.azure.com:443/workflows/0d102c65082647aeaddcd1a16170f087/triggers/When_a_HTTP_request_is_received/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2FWhen_a_HTTP_request_is_received%2Frun&sv=1.0&sig=_JLoQcsCRoQPjaNVNR2ju4VP0imerQ7pluVVlmjGoUI"  # Replace with your Logic App's HTTP trigger URL
$runbookOutput = @()  # Array to collect output for each VM

try
{
    "Logging in to Azure..."
    Connect-AzAccount -Identity
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}

########## This block is for to start the Vm's ##############

$vms = $VmName.split(',')

foreach ($vm in $vms) {
    if ($VmAction -eq "Startup") {
        Start-AzVM -ResourceGroupName $ResourceGroupName -Name $vm | Out-Null
        $objOut = [PSCustomObject]@{
            ResourceGroupName = $ResourceGroupName
            VMName            = $vm
            VMAction          = $VmAction
        }
        Write-Output ($objOut | ConvertTo-Json)
        $runbookOutput += $objOut
    }
}

# Convert the output to JSON or plain text
$outputString = $runbookOutput | ConvertTo-Json -Compress

# Send notification via Logic App
try {
    $body = @{
        status    = "Runbook completed"
        vmAction  = $VmAction
        runbookOutput = $outputString  
        resourceGroup = $ResourceGroupName
    } | ConvertTo-Json

    Invoke-RestMethod -Uri $LogicAppURL -Method Post -Body $body -ContentType 'application/json'
    Write-Output "Email notification triggered successfully."
}
catch {
    Write-Error "Failed to send the notification. Exception: $_.Exception"
}