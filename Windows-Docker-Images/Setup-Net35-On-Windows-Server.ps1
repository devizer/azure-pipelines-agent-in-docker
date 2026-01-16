function Install-NET35-On-Windows-Server() {
   $url=$null
   $osBuild=[Environment]::OsVersion.Version.Build
   if ($osBuild -eq 14393) { $url = @("https://archive.org/download/net35-ltsc2019/net35-ltsc2016.zip") }
   if ($osBuild -eq 17763) { $url = @("https://archive.org/download/net35-ltsc2019/net35-ltsc2019.zip", "https://sourceforge.net/projects/net35-bin/files/net35-ltsc2019.zip/download") }
   if ($osBuild -eq 20348) { $url = @("https://archive.org/download/net35-ltsc2019/net35-ltsc2022.zip", "https://sourceforge.net/projects/net35-bin/files/net35-ltsc2022.zip/download") }
   if ($osBuild -eq 26100) { $url = @("https://archive.org/download/net35-ltsc2019/net35-ltsc2025.zip", "https://sourceforge.net/projects/net35-bin/files/net35-ltsc2025.zip/download") }

   $folder=""
   if ($url) {
     Say "Downloading .NET 3.5 binaries for Windows Build $($osBuild): $url"
     $fileFillName = Combine-Path "$(Get-PS1-Repo-Downloads-Folder)" "net35-setup-for-build-$osBuild.zip"
     $okDownload = Download-File-FailFree-and-Cached "$fileFillName" $url
     $folder = Combine-Path "$(Get-PS1-Repo-Downloads-Folder)" "net35-setup-for-build-$osBuild"
     $okExtract = Extract-Archive-by-Default-Full-7z "$fileFillName" $folder
   }

   # NET-Framework-Features, NET-Framework-Core
   Say "LETS ROCK: Installing NET 3.5 (Install-WindowsFeature) On Windows Build $osBuild"
   Measure-Action "Install .NET 3.5 Framework" {
       if ($folder) {
         $res = Install-WindowsFeature NET-Framework-Features -Source "$folder"
       } else {
         $res = Install-WindowsFeature NET-Framework-Features
       }
       $res | ft -autosize | Out-String -width 1234
       if (-not $res.Success) { throw "Error Installing .NET 2.5. See Error Above" }
   }
}

Install-NET35-On-Windows-Server
