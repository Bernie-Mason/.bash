#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Builds, packs, and deploys NuGet packages locally with automatic version management.

.DESCRIPTION
    This script automates the workflow of creating local NuGet packages:
    1. Reads the current version from Directory.Build.Props
    2. Generates a new version with -local suffix
    3. Builds each specified project
    4. Packs each project with the local version
    5. Outputs packages to a local cache
    6. Updates Directory.Build.Props with the new local version

.PARAMETER Projects
    Array of project file paths (.csproj) to build and pack.

.PARAMETER LocalPackageCache
    Directory path where packed NuGet packages will be stored.

.PARAMETER BuildPropsPath
    Path to the Directory.Build.Props file containing version information.

.PARAMETER VersionElement
    XML element name in Directory.Build.Props that contains the version (e.g., "SharedVersion").

.PARAMETER Configuration
    Build configuration to use. Default is "Release".

.EXAMPLE
    .\nuget-pack-local.ps1 -Projects "C:\Dev\Shared\Project1.csproj","C:\Dev\Shared\Project2.csproj" `
                           -LocalPackageCache "C:\LocalPackages" `
                           -BuildPropsPath "C:\Dev\App\Directory.Build.Props" `
                           -VersionElement "SharedVersion"

.EXAMPLE
    # Using positional parameters
    .\nuget-pack-local.ps1 "C:\Dev\Shared\*.csproj" "C:\LocalPackages" "C:\Dev\App\Directory.Build.Props" "SharedVersion"
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string[]]$Projects,
    
    [Parameter(Mandatory=$true, Position=1)]
    [string]$LocalPackageCache,
    
    [Parameter(Mandatory=$true, Position=2)]
    [string]$BuildPropsPath,
    
    [Parameter(Mandatory=$true, Position=3)]
    [string]$VersionElement,
    
    [Parameter(Mandatory=$false)]
    [string]$Configuration = "Release"
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Get-CurrentVersion {
    param(
        [string]$PropsPath,
        [string]$ElementName
    )
    
    Write-Info "Reading current version from $PropsPath..."
    
    if (-not (Test-Path $PropsPath)) {
        throw "Directory.Build.Props file not found at: $PropsPath"
    }
    
    try {
        [xml]$xml = Get-Content $PropsPath -Raw
        
        $element = $null
        $propertyGroups = @($xml.Project.PropertyGroup)
        
        foreach ($group in $propertyGroups) {
            if ($group.$ElementName) {
                $element = $group.$ElementName
                break
            }
        }
        
        if (-not $element) {
            throw "Could not find element '$ElementName' in $PropsPath"
        }
        
        $versionText = $element.ToString()
        if ($versionText -match '\[([^\]]+)\]') {
            return $matches[1]
        } elseif ($versionText -match '^([\d\.]+)') {
            return $matches[1]
        } else {
            throw "Could not parse version from element '$ElementName': $versionText"
        }
    }
    catch {
        throw "Failed to read version from Directory.Build.Props: $_"
    }
}

function Set-LocalVersion {
    param(
        [string]$PropsPath,
        [string]$ElementName,
        [string]$NewVersion
    )
    
    Write-Info "Updating $ElementName to [$NewVersion] in Directory.Build.Props..."
    
    try {
        [xml]$xml = Get-Content $PropsPath -Raw
        
        # Find and update the element
        $propertyGroups = $xml.Project.PropertyGroup
        $updated = $false
        
        foreach ($group in $propertyGroups) {
            if ($group.$ElementName) {
                $group.$ElementName = "[$NewVersion]"
                $updated = $true
                break
            }
        }
        
        if (-not $updated) {
            throw "Could not find element '$ElementName' to update"
        }
        
        # Save with proper formatting
        $settings = New-Object System.Xml.XmlWriterSettings
        $settings.Indent = $true
        $settings.IndentChars = "  "
        $settings.NewLineChars = "`r`n"
        $settings.Encoding = [System.Text.UTF8Encoding]::new($false) # UTF-8 without BOM
        
        $writer = [System.Xml.XmlWriter]::Create($PropsPath, $settings)
        try {
            $xml.Save($writer)
            Write-Success "Updated $ElementName to [$NewVersion]"
        }
        finally {
            $writer.Close()
        }
    }
    catch {
        throw "Failed to update Directory.Build.Props: $_"
    }
}

function Build-Project {
    param(
        [string]$ProjectPath,
        [string]$Config
    )
    
    Write-Info "Building $ProjectPath..."
    
    $result = dotnet build $ProjectPath --configuration $Config 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed for $ProjectPath"
        Write-Host $result
        throw "Build failed with exit code $LASTEXITCODE"
    }
    
    Write-Success "Build completed for $ProjectPath"
}

function Pack-Project {
    param(
        [string]$ProjectPath,
        [string]$Config,
        [string]$Version,
        [string]$OutputDir
    )
    
    Write-Info "Packing $ProjectPath with version $Version..."
    
    $packArgs = @(
        "pack",
        $ProjectPath,
        "--configuration", $Config,
        "--output", $OutputDir,
        "/p:Version=$Version",
        "--include-symbols",
        "--include-source",
        "--no-build"
    )
    
    $result = & dotnet $packArgs 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Pack failed for $ProjectPath"
        Write-Host $result
        throw "Pack failed with exit code $LASTEXITCODE"
    }
    
    Write-Success "Pack completed for $ProjectPath"
}

function Resolve-ProjectPaths {
    param([string[]]$ProjectPatterns)
    
    $resolvedProjects = @()
    
    foreach ($pattern in $ProjectPatterns) {
        if ($pattern -match '[\*\?]') {
            $matched = Get-Item $pattern -ErrorAction SilentlyContinue
            if ($matched) {
                $resolvedProjects += $matched | ForEach-Object { $_.FullName }
            } else {
                Write-Warning "No projects found matching pattern: $pattern"
            }
        } else {
            if (Test-Path $pattern) {
                $resolvedProjects += (Get-Item $pattern).FullName
            } else {
                Write-Warning "Project not found: $pattern"
            }
        }
    }
    
    return $resolvedProjects
}


try {
    Write-Host " NuGet Local Package Builder" -ForegroundColor Cyan
    
    # Validate and resolve inputs
    $BuildPropsPath = (Resolve-Path $BuildPropsPath).Path
    $LocalPackageCache = (New-Item -ItemType Directory -Path $LocalPackageCache -Force).FullName
    
    Write-Info "Configuration:"
    Write-Host "  Build Configuration: $Configuration"
    Write-Host "  Local Package Cache: $LocalPackageCache"
    Write-Host "  Directory.Build.Props: $BuildPropsPath"
    Write-Host "  Version Element: $VersionElement"
    Write-Host ""
    
    $currentVersion = Get-CurrentVersion -PropsPath $BuildPropsPath -ElementName $VersionElement
    
    if ($currentVersion -match '^(.+)-local$') {
        $baseVersion = $matches[1]
        
        # Parse version parts (e.g., "3.13.5" -> major.minor.patch)
        if ($baseVersion -match '^(\d+)\.(\d+)\.(\d+)(.*)$') {
            $major = $matches[1]
            $minor = $matches[2]
            $patch = [int]$matches[3]
            $suffix = $matches[4]  # Any additional suffix like -beta, -alpha
            
            $patch++
            $localVersion = "$major.$minor.$patch$suffix-local"
        } else {
            Write-Warning "Unexpected version format: $baseVersion. Appending -local.2"
            $localVersion = "$currentVersion.2"
        }
    } else {
        $localVersion = "$currentVersion-local"
    }
    
    Write-Success "Current version: $currentVersion"
    Write-Success "New local version: $localVersion"
    Write-Host ""
    
    $resolvedProjects = @(Resolve-ProjectPaths -ProjectPatterns $Projects)
    
    if ($resolvedProjects.Count -eq 0) {
        throw "No valid projects found to pack"
    }
    
    Write-Info "Projects to pack ($($resolvedProjects.Count)):"
    foreach ($proj in $resolvedProjects) {
        Write-Host "  - $proj"
    }
    Write-Host ""
    
    Write-Info "Building projects..."
    foreach ($project in $resolvedProjects) {
        Build-Project -ProjectPath $project -Config $Configuration
    }
    Write-Host ""
    
    Write-Info "Packing projects..."
    foreach ($project in $resolvedProjects) {
        Pack-Project -ProjectPath $project -Config $Configuration -Version $localVersion -OutputDir $LocalPackageCache
    }
    Write-Host ""
    
    # Update Directory.Build.Props
    Set-LocalVersion -PropsPath $BuildPropsPath -ElementName $VersionElement -NewVersion $localVersion
    Write-Host ""
    
    Write-Success "All operations completed successfully!"
    Write-Host ""
    Write-Host "Summary:" -ForegroundColor Cyan
    Write-Host "  Projects built and packed: $($resolvedProjects.Count)"
    Write-Host "  Package version: $localVersion"
    Write-Host "  Packages location: $LocalPackageCache"
    Write-Host "  Directory.Build.Props updated: $BuildPropsPath"
    Write-Host ""
}
catch {
    Write-Error "Script failed: $_"
    exit 1
}