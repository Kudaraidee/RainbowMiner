﻿
$ConfigFile = ".\Config\config.txt"

if (Test-Path $ConfigFile) {
    try {
        $Config_Content = Get-Content $ConfigFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($Config_Content.MinerStatusKey -match "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$") {
            $Result = Invoke-RestMethod "https://api.rbminer.net/reset_workers.php?user=$($Config_Content.MinerStatusKey)" -timeout 10 -UseBasicParsing
            if ($Result.status) {
                $Data = "The signal to delete all offline workers was successfully sent to api.rbminer.net."
            } else {
                $Data = "Failed to send reset signal to api.rbminer.net."
            }
            $Result = $null
            Remove-Variable -Name Result -ErrorAction Ignore
        } else {
            $Data = "No valid MinerStatusKey found in config.txt"
        }
    } catch {
        $Data = "Error: $($_.Exception.Message)"
    }
} else {
    $Data = "config.txt not found!"
}

Write-Host $Data
