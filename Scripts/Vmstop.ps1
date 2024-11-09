


$VmName = "vm-1,vm-2,vm-3,vm-4,vm-5,vm-6,vm-7,vm-8,vm-9,vm-10"
$ResourceGroupName = "VMautomation-rg"                               
$VmAction = "Shutdown"
$LogicAppURL = "https://prod-50.eastus2.logic.azure.com:443/workflows/35c4e18ba2fc46faa6546d077b78ec0d/triggers/When_a_HTTP_request_is_received/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2FWhen_a_HTTP_request_is_received%2Frun&sv=1.0&sig=jNNwhDpWHrTeLG-NLL1X5xl6sr0rb5Fkp37r7Ik7k4I"  # Replace with your Logic App's HTTP trigger URL
$runbookOutput = @()  # Array to collect output for each VM

try {
    "Logging in to Azure..."
    Connect-AzAccount -Identity
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}


########## This block is for stoping the VMs ##############


$vms = $VmName.split(',')

foreach ($vm in $vms) {
    if ($VmAction -eq "Shutdown") {
        Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $vm | Out-Null
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
