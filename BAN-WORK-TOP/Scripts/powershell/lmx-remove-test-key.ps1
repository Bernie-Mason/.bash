Function Test-RegistryValue {
    param(
        [Alias("PSPath")]
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [String]$Path
        ,
        [Parameter(Position = 1, Mandatory = $true)]
        [String]$Name
        ,
        [Switch]$PassThru
    ) 
    process{
	    if (Test-Path $Path) {
	        $Key = Get-Item -LiteralPath $Path
	        if ($Key.GetValue($Name, $null) -ne $null) {
	            if ($PassThru) {
	                Get-ItemProperty $Path $Name
	            } else {
	                return $true
	            }
	        } else {
	            return $false
	        }
	    } else {
	        return $false
	    }
    }
}

if (Test-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Sensory Software" -Name "Subscriptions") {
	Write-Output "Removing registry entry:"
	Remove-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Sensory Software" -Name "Subscriptions" -Verbose
}
else {
	Write-Output "Registry does not exist. Nothing to remove."
}


if (Test-Path "HKLM:\SOFTWARE\Policies\Sensory Software") {
	Write-Output "Removing registry entry folder:"
	Remove-Item -Path "HKLM:\SOFTWARE\Policies\Sensory Software" -Verbose
}
else {
	Write-Output "Registry folder does not exist. Nothing to remove."
}
