$NdpPath = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP'

# Функция для определения маркетингового имени по номеру релиза
function Get-NetName($release) {
    if ($release -ge 533320) { return "4.8.1" }
    if ($release -ge 528040) { return "4.8" }
    if ($release -ge 461808) { return "4.7.2" }
    if ($release -ge 461308) { return "4.7.1" }
    if ($release -ge 460798) { return "4.7" }
    if ($release -ge 394802) { return "4.6.2" }
    if ($release -ge 394254) { return "4.6.1" }
    if ($release -ge 393295) { return "4.6" }
    if ($release -ge 379893) { return "4.5.2" }
    if ($release -ge 378675) { return "4.5.1" }
    if ($release -ge 378389) { return "4.5" }
    return ""
}

# Собираем данные
$keys = Get-ChildItem $NdpPath | Where-Object { $_.PSChildName -match '^v\d' }
$results = New-Object System.Collections.Generic.List[PSObject]

foreach ($key in $keys) {
    $path = $key.PSPath
    $verName = $key.PSChildName
    
    # Проверяем корень (для 2.0-3.5) и подразделы Full/Client (для 4.0+)
    $subKeys = @('', 'Full', 'Client')
    
    foreach ($sub in $subKeys) {
        $fullPath = $path
        if ($sub -ne '') { $fullPath = Join-Path $path $sub }
        
        $item = Get-ItemProperty -Path $fullPath -ErrorAction SilentlyContinue
        
        if ($item -and $item.Version -and ($item.Version -ne '4.0.0.0')) {
            # Формируем читаемое имя ветки
            $branch = $verName
            if ($sub -ne '') { $branch = "$verName ($sub)" }
            
            # Получаем дружественное имя версии 4.x
            $friendly = ""
            if ($item.Release) { $friendly = Get-NetName $item.Release }
            
            # Определяем Service Pack
            $sp = 0
            if ($item.SP -ne $null) { $sp = $item.SP }

            # Создаем объект (совместимо с PS 3.0)
            $obj = New-Object PSObject -Property @{
                Branch        = $branch
                "Build Number" = $item.Version
                SP            = $sp
                Release       = $item.Release
                FriendlyName  = $friendly
            }
            $results.Add($obj)
        }
    }
}

# Вывод таблицы
$results | Select-Object Branch, "Build Number", SP, Release, FriendlyName | Sort-Object "Build Number" | Format-Table -AutoSize
