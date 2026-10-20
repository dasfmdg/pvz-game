# 本地便携 MySQL 实例管理（开发用，Windows）
#
# 用途：在不动系统服务、不影响其它项目 data 目录的前提下，为 pvz-game 单独起一个 MySQL 实例。
#   - 独立 datadir：%LOCALAPPDATA%\pvz-game-mysql\data
#   - 独立端口：3307（避开默认 3306）
#
# 用法：
#   powershell -File backend/scripts/mysql_local.ps1 start     # 初始化(首次)并启动
#   powershell -File backend/scripts/mysql_local.ps1 stop      # 关闭
#   powershell -File backend/scripts/mysql_local.ps1 status    # 查看状态
#
# 可用环境变量覆盖：
#   PVZ_MYSQL_BASE   便携 MySQL 安装目录（默认 D:\tools\mysql-8.0.36-winx64）
#   PVZ_MYSQL_PORT   实例端口（默认 3307）

param(
    [Parameter(Position = 0)]
    [ValidateSet('start', 'stop', 'status')]
    [string]$Action = 'status'
)

$ErrorActionPreference = 'Stop'

$Base = if ($env:PVZ_MYSQL_BASE) { $env:PVZ_MYSQL_BASE } else { 'D:\tools\mysql-8.0.36-winx64' }
$Port = if ($env:PVZ_MYSQL_PORT) { [int]$env:PVZ_MYSQL_PORT } else { 3307 }
$Root = Join-Path $env:LOCALAPPDATA 'pvz-game-mysql'
$Data = Join-Path $Root 'data'
$Mysqld = Join-Path $Base 'bin\mysqld.exe'
$Mysql = Join-Path $Base 'bin\mysql.exe'
$MysqlAdmin = Join-Path $Base 'bin\mysqladmin.exe'

function Test-Listening {
    return [bool](Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
}

switch ($Action) {
    'start' {
        if (-not (Test-Path $Mysqld)) { throw "找不到 mysqld：$Mysqld（可用 PVZ_MYSQL_BASE 指定安装目录）" }
        if (Test-Listening) { Write-Output "已在运行（端口 $Port）"; break }

        if (-not (Test-Path (Join-Path $Data 'mysql'))) {
            New-Item -ItemType Directory -Force -Path $Data | Out-Null
            Write-Output "初始化 datadir：$Data"
            & $Mysqld --initialize-insecure --basedir="$Base" --datadir="$Data"
        }

        Write-Output "启动实例（端口 $Port，datadir $Data）"
        Start-Process -FilePath $Mysqld -ArgumentList @(
            "--basedir=$Base", "--datadir=$Data", "--port=$Port", "--bind-address=127.0.0.1"
        ) -WindowStyle Hidden

        foreach ($attempt in 1..60) {
            & $MysqlAdmin '--host=127.0.0.1' "--port=$Port" '--user=root' ping 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { Write-Output "就绪：127.0.0.1:$Port"; break }
            Start-Sleep -Milliseconds 500
        }
        if (-not (Test-Listening)) { throw "实例未能在 30s 内就绪，请检查 $Root 下的错误日志" }
    }
    'stop' {
        if (-not (Test-Listening)) { Write-Output '未在运行'; break }
        & $MysqlAdmin '--host=127.0.0.1' "--port=$Port" '--user=root' shutdown
        Write-Output '已关闭'
    }
    'status' {
        if (Test-Listening) {
            Write-Output "运行中：127.0.0.1:$Port"
            & $Mysql '--host=127.0.0.1' "--port=$Port" '--user=root' '--protocol=TCP' -e 'select version() as version'
        }
        else {
            Write-Output "未运行（端口 $Port）；启动：powershell -File backend/scripts/mysql_local.ps1 start"
        }
    }
}
