param (
    [bool]$init,
    [string]$add,
    [string]$remove,
    [string]$global,
    [string]$shell,
    [bool]$versions
)

# Check if the script is run with administrator privileges
function Is-Admin {
    try {
        # Check if the current user has administrator privileges
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Init {
    param (
        [Parameter(Mandatory = $false)]
        [ValidateSet("User", "Machine")]
        [string]$Scope = "User"  # "User" for user-level, "Machine" for system-level (requires admin privileges)
    )

    # Get the current script directory
    $scriptPath = $PSScriptRoot

    if (-not (Test-Path $scriptPath)) {
        Write-Host "Unable to get the current script path. Please check how the script is executed." -ForegroundColor Red
        return
    }

    # Get the current PATH
    $currentPath = [Environment]::GetEnvironmentVariable("Path", $scope)

    # Check if the path already exists
    if ($currentPath -split ';' -contains $scriptPath) {
        Write-Host "The path is already in $scope level PATH. No need to add it again." -ForegroundColor Yellow
        return
    }

    # Add the current script path to PATH
    $newPath = "$scriptPath;$currentPath"
    [Environment]::SetEnvironmentVariable("Path", $newPath, $scope)

    Write-Host "The current script path has been added to $scope level PATH:" -ForegroundColor Green
    # Write-Host $newPath
}

function Add {
    param (
        [string]$Path
    )
    # Write-Host $Path
    $folderName = (Split-Path $Path -Leaf)
    
    if ($JSON_DATA.PSObject.Properties[$folderName]) {
        Write-Host "Updating version $folderName, Path: $Path"
        $JSON_DATA.$folderName = $Path
    }
    else {
        Write-Host "Adding version $folderName, Path: $Path"
        $JSON_DATA | Add-Member -MemberType NoteProperty -Name "$folderName" -Value "$Path"
    }
}

function Global {
    param (
        [string]$Version
    )

    # If no admin privileges, display a message and exit
    if (-not (Is-Admin)) {
        Write-Host "Current user does not have admin privileges. Please run this script as an administrator." -ForegroundColor Red
        return
    }

    # Get the path of the specified version
    if ($JSON_DATA.PSObject.Properties[$Version]) {
        $javaHome = $JSON_DATA.$Version
        Write-Host "The JAVA_HOME path being used is: $javaHome" -ForegroundColor Green

        # Set JAVA_HOME environment variable
        [Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "Machine")

        # Set CLASSPATH environment variable
        $classPath = ".;%JAVA_HOME%\lib\dt.jar;%JAVA_HOME%\lib\tools.jar;"
        [Environment]::SetEnvironmentVariable("CLASSPATH", $classPath, "Machine")

        # Get the current PATH environment variable
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        
        # Check if PATH contains %JAVA_HOME%\bin and %JAVA_HOME%\jre\bin
        $javaBinPath = "%JAVA_HOME%\bin"
        $javaJreBinPath = "%JAVA_HOME%\jre\bin"
        
        if ($currentPath -notmatch [regex]::Escape($javaBinPath)) {
            $currentPath = "$currentPath;%JAVA_HOME%\bin"
        }
        
        if ($currentPath -notmatch [regex]::Escape($javaJreBinPath)) {
            $currentPath = "$currentPath;%JAVA_HOME%\jre\bin"
        }
        
        # Update PATH environment variable
        [Environment]::SetEnvironmentVariable("Path", $currentPath, "Machine")
        Write-Host "Updated PATH variable: $currentPath"
        
        Write-Host "JAVA_HOME, CLASSPATH, and PATH have been updated." -ForegroundColor Green
    }
    else {
        Write-Host "The specified Java version $Version path was not found." -ForegroundColor Red
    }
}

function Shell {
    param (
        [string]$Version
    )

    # Get the path of the specified version
    if ($JSON_DATA.PSObject.Properties[$Version]) {
        $javaHome = $JSON_DATA.$Version
        Write-Host "The JAVA_HOME path being used is: $javaHome" -ForegroundColor Green

        $env:JAVA_HOME = "$javaHome"
        $env:PATH = "$env:JAVA_HOME\bin;$env:JAVA_HOME\jre\bin;$env:PATH"
    }
    else {
        Write-Host "The specified Java version $Version path was not found." -ForegroundColor Red
    }
}

function Remove {
    param (
        [string]$Version
    )

    # Check if the specified version exists
    if ($JSON_DATA.PSObject.Properties[$Version]) {
        # Remove the specified version field
        $JSON_DATA.PSObject.Properties.Remove($Version)
        Write-Host "Successfully removed version $Version" -ForegroundColor Green
    }
    else {
        Write-Host "The specified Java version $Version was not found." -ForegroundColor Red
    }
}

function Versions {
    Write-Host $JSON_DATA
}

$JSON_FILE = Join-Path -Path $PSScriptRoot -ChildPath "versions.json"

# Check if the file exists
if (Test-Path $JSON_FILE) {
    # If it exists, read the file
    $JSON_DATA = Get-Content -Path $JSON_FILE -Raw | ConvertFrom-Json
}
else {
    # If it does not exist, create a new hashtable to store paths
    $JSON_DATA = '{}' | ConvertFrom-Json
}

if ($init) {
    Init -Scope "User"
}
elseif ($add) {
    Add -Path "$add"
}
elseif ($global) {
    Global -Version $global
}
elseif ($versions) {
    Versions
}
elseif ($shell) {
    Shell -Version $shell
}
elseif ($remove) {
    Remove -Version $remove
}
else {
    Write-Host "Unknown parameter"
}

$JSON_DATA | ConvertTo-Json -Depth 3 | Set-Content -Path $JSON_FILE
