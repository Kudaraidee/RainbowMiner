using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Wallets,
    [PSCustomObject]$Params,
    [alias("WorkerName")]
    [String]$Worker,
    [TimeSpan]$StatSpan,
    [String]$DataWindow = "estimate_current",
    [Bool]$InfoOnly = $false,
    [Bool]$AllowZero = $false,
    [String]$StatAverage = "Minute_10",
    [String]$StatAverageStable = "Week"
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Pool_Fee = 1

$Pool_Request = [PSCustomObject]@{}

try {
    $Pool_Request = Invoke-RestMethodAsync "https://api.rbminer.net/data/icemining2.json" -tag $Name -cycletime 120
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (-not ($Pool_Request | Measure-Object).Count) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

[hashtable]$Pool_RegionsTable = @{}
$Pool_Request.region | Select-Object -Unique | Foreach-Object {$Pool_RegionsTable.$_ = Get-Region $_}

$Pool_Request | Where-Object {$Pool_Currency = $_.symbol; $Wallets.$Pool_Currency -or $InfoOnly} | ForEach-Object {
    
    if ($Pool_Coin = Get-Coin $Pool_Currency) {
        $Pool_Algorithm_Norm  = $Pool_Coin.Algo
        $Pool_CoinName   = $Pool_Coin.Name
    } else {
        $Pool_Algorithm_Norm  = Get-Algorithm $_.data.algo -CoinSymbol $Pool_Currency
        $Pool_CoinName   = $Pool_Currency
    }

    if (-not $InfoOnly) {
        $Stat = Set-Stat -Name "$($Name)_$($Pool_Currency)_Profit" -Value 0 -Duration $StatSpan -ChangeDetection $false -HashRate $_.data.hashrate -BlockRate $_.data.blocks24h -Difficulty $_.data.diff -Quiet
        if (-not $Stat.HashRate_Live -and -not $AllowZero) {return}
    }

    $Pool_Wallet   = "$(if ($_.walletprefix -and $Wallets.$Pool_Currency -notmatch "^$($_.walletprefix)") {$_.walletprefix})$($Wallets.$Pool_Currency -replace "\s")"
    $Pool_User     = "$($Pool_Wallet)$(if ($Pool_Algorithm_Norm -ne "SHA256ton") {".{workername:$Worker}"})"
    $Pool_Protocol = "stratum+$(if ($_.ssl) {"ssl"} else {"tcp"})"
    $Pool_Fee      = if ($_.data.fee -ne $null) {[double]$_.data.fee} else {$Pool_Fee}
    $Pool_Pass     = "$(if ($Params.$Pool_Currency) {$Params.$Pool_Currency} else {"x"})"

    foreach($Pool_Region in $_.region) {
        [PSCustomObject]@{
            Algorithm     = $Pool_Algorithm_Norm
			Algorithm0    = $Pool_Algorithm_Norm
            CoinName      = $Pool_CoinName
            CoinSymbol    = $Pool_Currency
            Currency      = $Pool_Currency
            Price         = 0
            StablePrice   = 0
            MarginOfError = 0
            Protocol      = $Pool_Protocol
            Host          = "$($_.host -replace "%region%",$Pool_Region)"
            Port          = $_.port
            User          = $Pool_User
            Pass          = $Pool_Pass
            Region        = $Pool_RegionsTable.$Pool_Region
            SSL           = if ($_.ssl) {$true} else {$false}
            Updated       = $Stat.Updated
            PoolFee       = $Pool_Fee
            Workers       = $_.data.workers
            Hashrate      = $Stat.HashRate_Live
            BLK           = $Stat.BlockRate_Average
            TSL           = $_.data.timesincelast
            Difficulty    = $Stat.Diff_Average
            SoloMining    = if ($_.solo) {$true} else {$false}
            WTM           = $true
            EthMode       = if ($Pool_Algorithm_Norm -eq "SHA256ton") {"icemining"} else {$null}
            Name          = $Name
            Penalty       = 0
            PenaltyFactor = 1
            Disabled      = $false
            HasMinerExclusions = $false
            Price_0       = 0.0
            Price_Bias    = 0.0
            Price_Unbias  = 0.0
            Wallet        = $Pool_Wallet
            Worker        = "{workername:$Worker}"
            Email         = $Email
        }
    }
}
