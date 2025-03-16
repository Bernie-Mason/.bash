if (!(Test-Path "HKLM:\SOFTWARE\Policies\Sensory Software")) {
	Write-Output "Creating new folder for registry entry:"
	New-Item -Path "HKLM:\SOFTWARE\Policies\Sensory Software" -Verbose
}

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

if (!(Test-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Sensory Software" -Name "Subscriptions")){
	Write-Output "Creating new registry entry:"
	New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Sensory Software" -Name "Subscriptions" -Value "E0FB-4A54-4EF4-8614+B3C7792FAEC4" -Verbose
}
else{
	Write-Output "Registry entry already exists:"
	Get-ItemProperty "HKLM:\SOFTWARE\Policies\Sensory Software" "Subscriptions" -Verbose
}