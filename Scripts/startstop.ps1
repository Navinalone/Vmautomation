Param(
    [string]$VmName,             
    [string]$ResourceGroupName,        
    [ValidateSet("Startup", "Shutdown")]
    [string]$VmAction                  
)
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
    }
}
########## This block is for to stop the Vm's ##############
foreach ($vm in $vms) {
    if ($VmAction -eq "Shutdown") {
        Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $vm -Force | Out-Null
        $objOut = [PSCustomObject]@{
            ResourceGroupName = $ResourceGroupName
            VMName            = $vm
            VMAction          = $VmAction
        }
        Write-Output ($objOut | ConvertTo-Json)
    }
}
