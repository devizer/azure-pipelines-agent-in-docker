$NdpPath = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP'

function Get-NetName($rel) {
    if ($null -eq $rel) { return "" }
    if ($rel -ge 533320) { return "4.8.1" }
    if ($rel -ge 528040) { return "4.8" }
    if ($rel -ge 461808) { return "4.7.2" }
    if ($rel -ge 461308) { return "4.7.1" }
    if ($rel -ge 460798) { return "4.7" }
    if ($rel -ge 394802) { return "4.6.2" }
    if ($rel -ge 394254) { return "4.6.1" }
    if ($rel -ge 393295) { return "4.6" }
    if ($rel -ge 379893) { return "4.5.2" }
    if ($rel -ge 378675) { return "4.5.1" }
    if ($rel -ge 378389) { return "4.5" }
    return "4.0"
}

$keys = Get-ChildItem $NdpPath | Where-Object { $_.PSChildName -match '^v\d' }
$results = New-Object System.Collections.Generic.List[PSObject]

foreach ($key in $keys) {
    $verName = $key.PSChildName
    $subKeys = @('', 'Full', 'Client')
    
    foreach ($sub in $subKeys) {
        $fullPath = $key.PSPath
        if ($sub -ne '') { $fullPath = Join-Path $key.PSPath $sub }
        
        $item = Get-ItemProperty -Path $fullPath -ErrorAction SilentlyContinue
        
        if ($item -and $item.Version -and ($item.Version -ne '4.0.0.0')) {
            $currentSP = $item.SP
            $currentVer = $item.Version
            $currentRel = $item.Release
            
            $friendly = ""
            if ($currentRel) {
                $friendly = Get-NetName $currentRel
            } else {
                $friendly = $currentVer
                if ($null -ne $currentSP -and $currentSP -gt 0) {
                    $friendly = "$friendly SP$currentSP"
                }
            }

            $obj = New-Object PSObject -Property @{
                Branch       = if ($sub -ne '') { "$verName ($sub)" } else { $verName }
                Build        = $currentVer
                SP           = if ($null -ne $currentSP) { $currentSP } else { 0 }
                Release      = $currentRel
                FriendlyName = $friendly
            }
            $results.Add($obj)
        }
    }
}

$results | Select-Object Branch, Build, SP, Release, FriendlyName -Unique | Sort-Object Build | Format-Table -AutoSize
