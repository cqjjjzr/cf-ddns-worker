function CF_Is_IPv4_Public($addr) {
    if ($addr -eq "0.0.0.0") {
        return $false
    }
    $parts = $addr.Split(".")
    if ($parts.Count -ne 4) { return $false }
    else 
    {
        $part2 = $parts[1] -as [int]
        if ($part2 -eq $null) { return $false }
        if ($parts[0] -eq "10" -or `
            $parts[0] -eq "127" -or `
            ($parts[0] -eq "192" -and $parts[1] -eq "168") -or `
            ($parts[0] -eq "169" -and $parts[1] -eq "254") -or `
            ($parts[0] -eq "172" -and $part2 -ge 16 -and $part2 -le 31)) {
            return $false
        }
    }
    return $true
}

function CF_Is_IPv6_Public([string]$addr) {
    return -not ($addr.Contains("%") -or $addr.StartsWith(":") -or $addr.StartsWith("fe80") -or $addr.StartsWith("fc") -or $addr.StartsWith("fd"))
}

function CF_Extract_IPv4_IP($addresses) {
    $addresses = $addresses.IPAddress | Where-Object { CF_Is_IPv4_Public $_ }
    if ($addresses.Count -eq 0) {
        throw "No public IPv4 address found."
    }
    return $addresses[0]
}

function CF_Extract_IPv6_IP($addresses) {
    $addresses = $addresses.IPAddress | Where-Object { (CF_Is_IPv6_Public $_) -or $CF_IPv6_NIC_Allow_LinkLocal }
    if ($addresses.Count -eq 0) {
        throw "No public IPv6 address found."
    }
    
    return $addresses[0]
}

function CF_Obtain_Public_IP($ipv6, [ScriptBlock] $updateBlock, $nicIndex, $nicAutoPublic) {
    $addrFamily = $ipv6 ? "IPv6": "IPv4"
    Write-Host ("Retrieving Public IP for " + $addrFamily)
    if ($updateBlock -ne $null) {
        return (Invoke-Command -ScriptBlock $updateBlock)
    }
    if ($nicIndex -gt 0) {
        $result = @(Get-NetIPAddress -InterfaceIndex $nicIndex -AddressFamily $addrFamily)
        if ($result.Count -le 1) {
            throw "No valid address found on NIC $nicIndex."
        }
        if ($ipv6) {
            return (CF_Extract_IPv6_IP $result)
        }
        return $result[0].IPAddress
    }
    if ($nicAutoPublic) {
        $result = @(Get-NetIPAddress -AddressFamily $addrFamily)
        if ($ipv6) {
            $CF_IPv6_NIC_Allow_LinkLocal = $false
            return (CF_Extract_IPv6_IP $result)
        }
        return (CF_Extract_IPv4_IP $result)
    }
    return $null
}

function CF_HMAC_Sign($token, $message) {
    $crypto = New-Object System.Security.Cryptography.HMACSHA256
    $crypto.key = [Text.Encoding]::ASCII.GetBytes($token)
    $signature = $crypto.ComputeHash([Text.Encoding]::ASCII.GetBytes($message))
    $signature = [Convert]::ToBase64String($signature)
    return $signature
}

function CF_Update($ipv6) {
    $addrFamily = $ipv6 ? "IPv6": "IPv4"
    Write-Host "Updating for" $addrFamily

    try {
        $ip = (CF_Obtain_Public_IP $ipv6 `
            ($ipv6 ? $CF_IPv6_Update_Block : $CF_IPv4_Update_Block) `
            ($ipv6 ? $CF_IPv6_NIC_Index : $CF_IPv4_NIC_Index) `
            ($ipv6 ? $CF_IPv6_NIC_Auto_Public : $CF_IPv4_NIC_Auto_Public))
        Write-Host "Got IP address" $ip
        Write-Host "Updating to domain " $CF_Domain
        $request = @{
            id = $CF_Token_ID;
            domain = $CF_Domain;
            type = $addrFamily.ToLower();
            addr = $ip;
            timestamp = (Get-Date(Get-Date).ToUniversalTime() -UFormat %s) - 60;
        }
        $requestText = $request | ConvertTo-Json -Compress
        $sign = (CF_HMAC_Sign $CF_Token $requestText)
        Invoke-WebRequest -Uri $CF_Worker_URL -Method Post `
            -ContentType "application/json" -Body $requestText `
            -Headers @{Authorization = $sign} -SkipHeaderValidation
        Write-Host "Success!"
    } catch {
        Write-Host "Failed to update IP address!"
        Write-Host $_
    }
}

function CF_Main() {
    . (Join-Path $PSScriptRoot "config.ps1") # Note the dot

    if ($CF_IPv4_Enabled) { CF_Update $false }
    if ($CF_IPv6_Enabled) { CF_Update $true }
}

CF_Main