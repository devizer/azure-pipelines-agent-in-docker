function Install-NET35-On-Windows-Server() {
   $url=""
   $osBuild=[Environment]::OsVersion.Version.Build
   if ($osBuild -eq 17763) { $url="https://sourceforge.net/projects/net35-bin/files/net35-ltsc2019.zip/download" }
   if ($osBuild -eq 20348) { $url="https://sourceforge.net/projects/net35-bin/files/net35-ltsc2022.zip/download" }
   if ($osBuild -eq 26100) { $url="https://sourceforge.net/projects/net35-bin/files/net35-ltsc2025.zip/download" } # NET-Framework-Features, NET-Framework-Core

   $folder=""
   if ($url) {
     echo "Downloading .NET 3.5 binaris for Windows Build $($osBuild): $url"
     $fileFillName=Combine-Path "$(Get-PS1-Repo-Downloads-Folder)" "net35-setup-for-build-$osBuild.zip"
     $okDownload = Download-File-FailFree-and-Cached "$fileFillName" "$url"
     $folder = Combine-Path "$(Get-PS1-Repo-Downloads-Folder)" "net35-setup-for-build-$osBuild"
     $okExtract = Extract-Archive-by-Default-Full-7z "$fileFillName" $folder
   }

   Measure-Action "Install .NET 3.5 Framwork" {
       if ($folder) {
         Install-WindowsFeature NET-Framework-Features -Source "$folder"
       } else {
         Install-WindowsFeature NET-Framework-Features
       }
   }
}

Install-NET35-On-Windows-Server
