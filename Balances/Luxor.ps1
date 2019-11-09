﻿param(
    $Config
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pools_Data = @(
    [PSCustomObject]@{symbol = "AION";    port = 3366; fee = 3.0; rpc = "aion"}
    [PSCustomObject]@{symbol = "GRIN";    port = 3000; fee = 2.0; rpc = "grin"}
    [PSCustomObject]@{symbol = "LOKI";    port = 9999; fee = 1.0; rpc = "loki"}
    [PSCustomObject]@{symbol = "VEIL";    port = 3033; fee = 0.0; rpc = "veil"}
    [PSCustomObject]@{symbol = "XMR";     port = 8888; fee = 2.0; rpc = "xmr"}
    [PSCustomObject]@{symbol = "YEC";     port = 6655; fee = 0.0; rpc = "yec"}
)

$Pools_Data | Where-Object {$Config.Pools.$Name.Wallets."$($_.symbol)"} | Foreach-Object {
    $Pool_Currency = $_.symbol
    $Pool_RpcPath  = $_.rpc

    $Request = [PSCustomObject]@{}

    $coinUnits = 1e18

    try {
        $Request = Invoke-RestMethodAsync "http://mining.luxor.tech/api/$($Pool_Currency)/user/$($Config.Pools.$Name.Wallets."$($_.symbol)")" -delay 100 -cycletime ($Config.BalanceUpdateMinutes*60) -timeout 15

        if (-not $Request -or -not $coinUnits) {
            Write-Log -Level Info "Pool Balance API ($Name) for $($Pool_Currency) returned nothing. "
        } else {
            [PSCustomObject]@{
                Caption     = "$($Name) ($Pool_Currency)"
                BaseName    = $Name
                Currency    = $Pool_Currency
                Balance     = [Decimal]$Request.balance / $coinUnits
                Pending     = 0
                Total       = [Decimal]$Request.balance / $coinUnits
                Paid        = [Decimal]$Request.total_payouts / $coinUnits
                Paid24h     = [Decimal]$Request.payouts_one_day / $coinUnits
                Payouts     = @(Get-BalancesPayouts $Request.payouts -Divisor $coinUnits)
                LastUpdated = (Get-Date).ToUniversalTime()
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Log -Level Verbose "Pool Balance API ($Name) for $($Pool_Currency) has failed. "
    }
}