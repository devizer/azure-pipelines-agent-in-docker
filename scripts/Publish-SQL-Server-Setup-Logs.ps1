$folders=@("C:\Program Files", "C:\Program Files (x86)", "$($Env:ProgramFiles)", "${Env:ProgramFiles(x86)}")
$folders=($folders | sort | Get-Unique)

if (-not "$($Env:SQL_SETUP_LOGS_FOLDER)") { 
  $Env:SQL_SETUP_LOGS_FOLDER="$($Env:USERPROFILE)\SQL-Server-Logs-$([System.DateTime]::Now.ToString("yyyy-MM-dd-HH-mm-ss"))"
}

Write-Host "SQL_SETUP_LOGS_FOLDER: '$($Env:SQL_SETUP_LOGS_FOLDER)'" -ForegroundColor Yellow
New-Item -ItemType Directory -Path $($Env:SQL_SETUP_LOGS_FOLDER) -EA SilentlyContinue | out-null

$folders | % { $folder=$_
  Write-Host "Folder: [$folder]"
  $sqlFolder=[System.IO.Path]::Combine($folder, "Microsoft SQL Server");
  Write-Host "SQL Folder: [$sqlFolder]"
  if ([System.IO.Directory]::Exists($sqlFolder)) {
  	Write-Host "  Exists SQL Folder: [$sqlFolder]"
  	Get-ChildItem -Path $sqlFolder -Directory -Force -ErrorAction SilentlyContinue | % { $ver=$_.Name; $verSubFolder=$_.FullName
  	  Write-Host "    VERSION Folder: [$verSubFolder]"
  	  $logFolder=[System.IO.Path]::Combine($verSubFolder, "Setup Bootstrap\LOG");
  	  if ([System.IO.Directory]::Exists($logFolder)) {
  	    Write-Host "      LOG FOLDER Found: [$logFolder]"
  	    Write-Host "      ROOT FOLDER Found: [$([System.IO.Path]::GetPathRoot($logFolder))]"
  	    $archiveName=$logFolder.Substring([System.IO.Path]::GetPathRoot($logFolder).Length).Replace("\", ([char]8594).ToString())
  	    Write-Host "      Archive Name: [$archiveName]"
  	    Write-Host "Pack '$logFolder'$([System.Environment]::NewLine)  to [$($Env:SQL_SETUP_LOGS_FOLDER)\$archiveName.7z]" -ForegroundColor Magenta
  	    7z a -mx=9 -ms=on -mqs=on "$($Env:SQL_SETUP_LOGS_FOLDER)\$archiveName.7z" "$logFolder"
  	  }
  	}
  }
}

exit 0

# "C:\Program Files (x86)\Microsoft SQL Server\90\Setup Bootstrap\LOG\"
# "C:\Program Files\Microsoft SQL Server\150\Setup Bootstrap\Log\"
