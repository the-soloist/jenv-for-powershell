param (
    [bool]$init,
    [string]$add,
    [string]$remove,
    [string]$global,
    [string]$shell,
    [bool]$versions
)

# 判断是否为管理员权限
function Is-Admin {
    try {
        # 检查是否具有管理员权限
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
        [string]$Scope = "User"  # "User" 表示用户级，"Machine" 表示系统级（需要管理员权限）
    )

    # 获取当前脚本所在目录
    $scriptPath = $PSScriptRoot

    if (-not (Test-Path $scriptPath)) {
        Write-Host "无法获取当前脚本路径，请检查脚本执行方式" -ForegroundColor Red
        return
    }

    # 获取当前 PATH
    $currentPath = [Environment]::GetEnvironmentVariable("Path", $scope)

    # 检查是否已存在当前路径
    if ($currentPath -split ';' -contains $scriptPath) {
        Write-Host "路径已存在于 $scope 级 PATH，无需重复添加" -ForegroundColor Yellow
        return
    }

    # 添加当前脚本路径到 PATH
    $newPath = "$scriptPath;$currentPath"
    [Environment]::SetEnvironmentVariable("Path", $newPath, $scope)

    Write-Host "当前脚本路径已添加到 $scope 级 PATH：" -ForegroundColor Green
    # Write-Host $newPath
}

function Add {
    param (
        [string]$Path
    )
    # Write-Host $Path
    $folderName = (Split-Path $Path -Leaf)
    
    if ($JSON_DATA.PSObject.Properties[$folderName]) {
        Write-Host "更新版本 $folderName，路径：$Path"
        $JSON_DATA.$folderName = $Path
    }
    else {
        Write-Host "添加版本 $folderName，路径：$Path"
        $JSON_DATA | Add-Member -MemberType NoteProperty -Name "$folderName" -Value "$Path"
    }
}

function Global {
    param (
        [string]$Version
    )

    # 如果没有管理员权限，则提示并退出
    if (-not (Is-Admin)) {
        Write-Host "当前用户没有管理员权限。请以管理员身份运行此脚本" -ForegroundColor Red
        return
    }

    # 获取指定版本路径
    if ($JSON_DATA.PSObject.Properties[$Version]) {
        $javaHome = $JSON_DATA.$Version
        Write-Host "使用的 JAVA_HOME 路径是：$javaHome" -ForegroundColor Green

        # 设置 JAVA_HOME 环境变量
        [Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "Machine")

        # 设置 CLASSPATH 环境变量
        $classPath = ".;%JAVA_HOME%\lib\dt.jar;%JAVA_HOME%\lib\tools.jar;"
        [Environment]::SetEnvironmentVariable("CLASSPATH", $classPath, "Machine")

        # 获取当前 PATH 环境变量
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        
        # 检查 PATH 中是否包含 %JAVA_HOME%\bin 和 %JAVA_HOME%\jre\bin
        $javaBinPath = "%JAVA_HOME%\bin"
        $javaJreBinPath = "%JAVA_HOME%\jre\bin"
        
        if ($currentPath -notmatch [regex]::Escape($javaBinPath)) {
            $currentPath = "$currentPath;%JAVA_HOME%\bin"
        }
        
        if ($currentPath -notmatch [regex]::Escape($javaJreBinPath)) {
            $currentPath = "$currentPath;%JAVA_HOME%\jre\bin"
        }
        
        # 更新 PATH 环境变量
        [Environment]::SetEnvironmentVariable("Path", $currentPath, "Machine")
        Write-Host "更新后PATH变量：$currentPath"
        
        Write-Host "JAVA_HOME, CLASSPATH 和 PATH 已更新" -ForegroundColor Green
    }
    else {
        Write-Host "未找到指定版本 $Version 的 Java 路径" -ForegroundColor Red
    }
}

function Shell {
    param (
        [string]$Version
    )

    # 获取指定版本路径
    if ($JSON_DATA.PSObject.Properties[$Version]) {
        $javaHome = $JSON_DATA.$Version
        Write-Host "使用的 JAVA_HOME 路径是：$javaHome" -ForegroundColor Green

        $env:JAVA_HOME = "$javaHome"
        $env:PATH = "$env:JAVA_HOME\bin;$env:JAVA_HOME\jre\bin;$env:PATH"
    }
    else {
        Write-Host "未找到指定版本 $Version 的 Java 路径" -ForegroundColor Red
    }
}

function Remove {
    param (
        [string]$Version
    )

    # 检查指定版本是否存在
    if ($JSON_DATA.PSObject.Properties[$Version]) {
        # 删除指定版本字段
        $JSON_DATA.PSObject.Properties.Remove($Version)
        Write-Host "已成功删除版本 $Version" -ForegroundColor Green
    }
    else {
        Write-Host "未找到指定版本 $Version" -ForegroundColor Red
    }
}


function Versions {
    Write-Host $JSON_DATA
}

$JSON_FILE = Join-Path -Path $PSScriptRoot -ChildPath "versions.json"

# 检查文件是否存在
if (Test-Path $JSON_FILE) {
    # 如果存在，读取文件
    $JSON_DATA = Get-Content -Path $JSON_FILE -Raw | ConvertFrom-Json
}
else {
    # 如果不存在，创建一个新的哈希表来存储路径
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
    Write-Host "未知参数"
}

$JSON_DATA | ConvertTo-Json -Depth 3 | Set-Content -Path $JSON_FILE
