# Network Discovery Service Test PowerShell Script

# Define Constants
$SERVICE_NAME = "_notesync._tcp"
$MIN_PORT = 50000
$MAX_PORT = 50100

# Check if running with administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script with administrator privileges"
    exit
}

# Test port availability
function Test-PortAvailability {
    param(
        [int]$StartPort,
        [int]$EndPort
    )
    
    Write-Host "Testing port range $StartPort to $EndPort..."
    $availablePorts = @()
    
    for ($port = $StartPort; $port -le $EndPort; $port++) {
        try {
            $listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $port)
            $listener.Start()
            $listener.Stop()
            $availablePorts += $port
            Write-Host "Port $port is available" -ForegroundColor Green
        } catch {
            Write-Host "Port $port is in use" -ForegroundColor Red
        }
    }
    
    return $availablePorts
}

# Test mDNS service discovery
function Test-MDNSDiscovery {
    Write-Host "Testing mDNS service discovery..."
    
    # Use nslookup to query mDNS service with timeout
    try {
        $job = Start-Job -ScriptBlock { 
            param($serviceName)
            # 使用完整的服务名称格式进行查询
            $fullServiceName = $serviceName
            if (-not $serviceName.EndsWith('.local')) {
                $fullServiceName = "$serviceName.local."
            }
            Write-Host "Querying mDNS service: $fullServiceName"
            nslookup -type=ANY -timeout=5 $fullServiceName 2>&1
        } -ArgumentList $SERVICE_NAME

        # 增加等待时间到15秒
        $completed = Wait-Job $job -Timeout 15
        if ($completed) {
            $result = Receive-Job $job
            Write-Host "Query result:"
            $result | ForEach-Object { Write-Host $_ }
            
            if ($result -match $SERVICE_NAME) {
                Write-Host "mDNS service discovered: $SERVICE_NAME" -ForegroundColor Green
            } else {
                Write-Host "mDNS service not found - Please check if the service is running and mDNS is enabled" -ForegroundColor Yellow
            }
        } else {
            Write-Host "mDNS query timed out after 10 seconds - Network might be blocking mDNS traffic" -ForegroundColor Yellow
            Stop-Job $job
        }
        Remove-Job $job -Force
    } catch {
        Write-Host "mDNS query failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    }
}

# Test network connectivity
function Test-NetworkConnectivity {
    param(
        [string]$TargetHost,
        [int]$Port
    )
    
    Write-Host "Testing network connection ${TargetHost}:${Port}..."
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connection = $tcpClient.BeginConnect($TargetHost, $Port, $null, $null)
        $success = $connection.AsyncWaitHandle.WaitOne(1000)
        
        if ($success) {
            $tcpClient.EndConnect($connection)
            Write-Host "Successfully connected to ${TargetHost}:${Port}" -ForegroundColor Green
        } else {
            Write-Host "Unable to connect to ${TargetHost}:${Port}" -ForegroundColor Red
        }
        
        $tcpClient.Close()
    } catch {
        Write-Host "Connection test failed: $_" -ForegroundColor Red
    }
}

# Main test flow
Write-Host "Starting network discovery service test..." -ForegroundColor Cyan

# 1. Test port availability
$availablePorts = Test-PortAvailability -StartPort $MIN_PORT -EndPort $MAX_PORT
Write-Host "Number of available ports: $($availablePorts.Count)"

# 2. Test mDNS service discovery
Test-MDNSDiscovery

# 3. Test local connection
Test-NetworkConnectivity -Host "localhost" -Port $MIN_PORT

Write-Host "Test completed" -ForegroundColor Cyan