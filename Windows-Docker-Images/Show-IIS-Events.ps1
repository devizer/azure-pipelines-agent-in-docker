$Sources = @("IIS-W3SVC-WP", "IIS-W3SVC", "ASP.NET*", "IIS-Configuration", "WAS")

Get-WinEvent -LogName Application | 
    Where-Object { $_.ProviderName -match ($Sources -join "|") } |
    Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message | 
    ft -autosize | Out-String -Width 1234
