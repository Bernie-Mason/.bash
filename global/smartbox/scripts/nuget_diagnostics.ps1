# NuGet Package Diagnostics Script
# Helps diagnose package restore issues with private and public feeds

param(
    [string]$ConfigFile = "",
    [switch]$Verbose
)

# Colors for better output
$Colors = @{
    Header = "Cyan"
    Success = "Green" 
    Warning = "Yellow"
    Error = "Red"
    Info = "White"
    Highlight = "Magenta"
}

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White",
        [switch]$NoNewline
    )
    
    # Fix: Check if the color exists in the hashtable, otherwise use default
    $colorValue = $Colors[$Color]
    if (-not $colorValue) {
        $colorValue = "White"
    }
    
    if ($NoNewline) {
        Write-Host $Message -ForegroundColor $colorValue -NoNewline
    }
    else {
        Write-Host $Message -ForegroundColor $colorValue
    }
}

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-ColorOutput "=" * 80 "Header"
    Write-ColorOutput " $Title" "Header"  
    Write-ColorOutput "=" * 80 "Header"
    Write-Host ""
}

function Get-NuGetSources {
    Write-ColorOutput "Fetching NuGet sources..." "Info"
    
    try {
        $sources = & nuget sources list -Format Detailed 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "NuGet command failed"
        }
        
        $sourceList = @()
        $currentSource = $null
        
        foreach ($line in $sources) {
            if ($line -match '^\s*\d+\.\s+(.+)\s+\[(.+)\]$') {
                if ($currentSource) {
                    $sourceList += $currentSource
                }
                $currentSource = @{
                    Name = $matches[1].Trim()
                    Status = $matches[2].Trim()
                    Url = ""
                }
            }
            elseif ($line -match '^\s+(.+)$' -and $currentSource) {
                $currentSource.Url = $matches[1].Trim()
            }
        }
        
        if ($currentSource) {
            $sourceList += $currentSource
        }
        
        return $sourceList
    }
    catch {
        Write-ColorOutput "Failed to get NuGet sources: $($_.Exception.Message)" "Error"
        return @()
    }
}

function Show-NuGetSources {
    param([array]$Sources)
    
    Write-Header "Available NuGet Sources"
    
    if ($Sources.Count -eq 0) {
        Write-ColorOutput "No NuGet sources found!" "Error"
        return
    }
    
    for ($i = 0; $i -lt $Sources.Count; $i++) {
        $source = $Sources[$i]
        $statusColor = if ($source.Status -eq "Enabled") { "Success" } else { "Warning" }
        
        Write-ColorOutput "  $($i + 1). " "Info" -NoNewline
        Write-ColorOutput "$($source.Name)" "Highlight" -NoNewline
        Write-ColorOutput " [$($source.Status)]" $statusColor -NoNewline
        Write-ColorOutput ""  # This creates the newline
        Write-ColorOutput "     $($source.Url)" "Info"
    }
}

function Test-SourceConnectivity {
    param(
        [string]$SourceUrl,
        [string]$SourceName
    )
    
    Write-ColorOutput "Testing connectivity to $SourceName..." "Info"
    
    try {
        if ($SourceUrl -match '^https?://') {
            $response = Invoke-WebRequest -Uri $SourceUrl -Method Head -TimeoutSec 10 -UseBasicParsing
            Write-ColorOutput "Source is reachable (Status: $($response.StatusCode))" "Success"
            return $true
        }
        else {
            Write-ColorOutput "Cannot test local/file source connectivity" "Warning"
            return $true
        }
    }
    catch {
        Write-ColorOutput "Source unreachable: $($_.Exception.Message)" "Error"  
        return $false
    }
}

function Get-PackagesFromSource {
    param(
        [string]$SourceName,
        [string]$SearchTerm = "",
        [int]$Take = 20
    )
    
    $searchParam = if ($SearchTerm) { "-Search $SearchTerm" } else { "" }
    
    Write-ColorOutput "Searching packages from source '$SourceName'..." "Info"
    
    try {
        $command = "nuget list $searchParam -Source `"$SourceName`" -AllVersions -NonInteractive"
        if ($Verbose) {
            Write-ColorOutput "Command: $command" "Info"
        }
        
        $packages = Invoke-Expression $command 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            throw "NuGet list command failed with exit code $LASTEXITCODE"
        }
        
        $packageList = @()
        foreach ($line in $packages) {
            if ($line -match '^(.+?)\s+(.+)$') {
                $packageList += @{
                    Name = $matches[1].Trim()
                    Version = $matches[2].Trim()
                }
            }
        }
        
        # Group by package name and get latest version
        $grouped = $packageList | Group-Object Name | ForEach-Object {
            $latest = $_.Group | Sort-Object { [System.Version]($_.Version -replace '[^0-9.].*$', '') } -Descending | Select-Object -First 1
            @{
                Name = $_.Name
                LatestVersion = $latest.Version
                TotalVersions = $_.Count
            }
        }
        
        return $grouped | Sort-Object Name | Select-Object -First $Take
        
    }
    catch {
        Write-ColorOutput "Failed to list packages: $($_.Exception.Message)" "Error"
        return @()
    }
}

function Show-PackageList {
    param(
        [array]$Packages,
        [string]$SourceName
    )
    
    Write-Header "Packages from Source: $SourceName"
    
    if ($Packages.Count -eq 0) {
        Write-ColorOutput "No packages found or source inaccessible!" "Error"
        return
    }
    
    Write-ColorOutput ("{0,-50} {1,-20} {2}" -f "Package Name", "Latest Version", "Total Versions") "Header"
    Write-ColorOutput ("-" * 80) "Header"
    
    foreach ($package in $Packages) {
        Write-ColorOutput ("{0,-50} " -f $package.Name) "Info" -NoNewline
        Write-ColorOutput ("{0,-20} " -f $package.LatestVersion) "Success" -NoNewline
        Write-ColorOutput ("{0}" -f $package.TotalVersions) "Highlight"
    }
}

function Get-PackageDetails {
    param(
        [string]$PackageName,
        [string]$SourceName
    )
    
    Write-Header "Package Details: $PackageName"
    
    Write-ColorOutput "Getting detailed information for '$PackageName' from '$SourceName'..." "Info"
    
    try {
        # Get all versions
        $command = "nuget list $PackageName -Source `"$SourceName`" -AllVersions -NonInteractive"
        $versions = Invoke-Expression $command 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get package versions"
        }
        
        $versionList = @()
        foreach ($line in $versions) {
            if ($line -match "^$PackageName\s+(.+)$") {
                $versionList += $matches[1].Trim()
            }
        }
        
        if ($versionList.Count -gt 0) {
            Write-ColorOutput "Found $($versionList.Count) version(s):" "Success"
            $versionList | Sort-Object { [System.Version]($_ -replace '[^0-9.].*$', '') } -Descending | ForEach-Object {
                Write-ColorOutput "   • $_" "Info"
            }
        }
        else {
            Write-ColorOutput "Package not found in source!" "Error"
        }
        
    }
    catch {
        Write-ColorOutput "Failed to get package details: $($_.Exception.Message)" "Error"
    }
}

function Clear-NuGetCaches {
    Write-Header "Clearing NuGet Caches"
    
    try {
        Write-ColorOutput "Clearing all NuGet caches..." "Info"
        & nuget locals all -clear
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Successfully cleared NuGet caches" "Success"
        }
        else {
            Write-ColorOutput "Some caches may not have been cleared" "Warning"
        }
    }
    catch {
        Write-ColorOutput "Failed to clear caches: $($_.Exception.Message)" "Error"
    }
}

function Show-CacheLocations {
    Write-Header "NuGet Cache Locations"
    
    try {
        Write-ColorOutput "Current NuGet cache locations:" "Info"
        & nuget locals all -list
    }
    catch {
        Write-ColorOutput "Failed to get cache locations: $($_.Exception.Message)" "Error"
    }
}

function Main {
    Write-Header "NuGet Package Diagnostics Tool"
    
    # Check if nuget.exe is available
    try {
        & nuget help | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "NuGet not available"
        }
    }
    catch {
        Write-ColorOutput "NuGet CLI not found! Please install nuget.exe and add it to PATH." "Error"
        Write-ColorOutput "Download from: https://www.nuget.org/downloads" "Info"
        return
    }
    
    $sources = Get-NuGetSources
    
    while ($true) {
        Write-Header "Main Menu"
        Write-ColorOutput "1. List NuGet sources" "Info"
        Write-ColorOutput "2. Test source connectivity" "Info"
        Write-ColorOutput "3. Browse packages from source" "Info"
        Write-ColorOutput "4. Search for specific package" "Info"
        Write-ColorOutput "5. Get package details" "Info"
        Write-ColorOutput "6. Show cache locations" "Info"
        Write-ColorOutput "7. Clear NuGet caches" "Info"
        Write-ColorOutput "8. Refresh source list" "Info"
        Write-ColorOutput "9. Exit" "Info"
        Write-Host ""
        
        $choice = Read-Host "Select an option (1-9)"
        
        switch ($choice) {
            "1" {
                Show-NuGetSources -Sources $sources
            }
            
            "2" {
                Show-NuGetSources -Sources $sources
                Write-Host ""
                $sourceIndex = Read-Host "Enter source number to test"
                if ($sourceIndex -match '^\d+$' -and [int]$sourceIndex -ge 1 -and [int]$sourceIndex -le $sources.Count) {
                    $selectedSource = $sources[[int]$sourceIndex - 1]
                    Test-SourceConnectivity -SourceUrl $selectedSource.Url -SourceName $selectedSource.Name
                }
                else {
                    Write-ColorOutput "Invalid source number!" "Error"
                }
            }
            
            "3" {
                Show-NuGetSources -Sources $sources
                Write-Host ""
                $sourceIndex = Read-Host "Enter source number to browse"
                if ($sourceIndex -match '^\d+$' -and [int]$sourceIndex -ge 1 -and [int]$sourceIndex -le $sources.Count) {
                    $selectedSource = $sources[[int]$sourceIndex - 1]
                    $packages = Get-PackagesFromSource -SourceName $selectedSource.Name
                    Show-PackageList -Packages $packages -SourceName $selectedSource.Name
                }
                else {
                    Write-ColorOutput "Invalid source number!" "Error"
                }
            }
            
            "4" {
                Show-NuGetSources -Sources $sources
                Write-Host ""
                $sourceIndex = Read-Host "Enter source number to search"
                if ($sourceIndex -match '^\d+$' -and [int]$sourceIndex -ge 1 -and [int]$sourceIndex -le $sources.Count) {
                    $selectedSource = $sources[[int]$sourceIndex - 1]
                    $searchTerm = Read-Host "Enter search term"
                    if ($searchTerm) {
                        $packages = Get-PackagesFromSource -SourceName $selectedSource.Name -SearchTerm $searchTerm
                        Show-PackageList -Packages $packages -SourceName $selectedSource.Name
                    }
                }
                else {
                    Write-ColorOutput "Invalid source number!" "Error"
                }
            }
            
            "5" {
                Show-NuGetSources -Sources $sources
                Write-Host ""
                $sourceIndex = Read-Host "Enter source number"
                if ($sourceIndex -match '^\d+$' -and [int]$sourceIndex -ge 1 -and [int]$sourceIndex -le $sources.Count) {
                    $selectedSource = $sources[[int]$sourceIndex - 1]
                    $packageName = Read-Host "Enter exact package name"
                    if ($packageName) {
                        Get-PackageDetails -PackageName $packageName -SourceName $selectedSource.Name
                    }
                }
                else {
                    Write-ColorOutput "Invalid source number!" "Error"
                }
            }
            
            "6" {
                Show-CacheLocations
            }
            
            "7" {
                $confirm = Read-Host "Are you sure you want to clear all caches? (y/N)"
                if ($confirm -eq 'y' -or $confirm -eq 'Y') {
                    Clear-NuGetCaches
                }
            }
            
            "8" {
                Write-ColorOutput "Refreshing source list..." "Info"
                $sources = Get-NuGetSources
                Write-ColorOutput "Source list refreshed" "Success"
            }
            
            "9" {
                Write-ColorOutput "Goodbye!" "Success"
                return
            }
            
            default {
                Write-ColorOutput "Invalid option! Please select 1-9." "Error"
            }
        }
        
        Write-Host ""
        Read-Host "Press Enter to continue..."
        Clear-Host
    }
}

# Run the main function
Main