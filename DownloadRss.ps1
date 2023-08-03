$url = "https://rss.art19.com/how-i-built-this"

# Set the directory where the downloaded episodes will be saved
$directory = "D:\Temp\Podcasts"

$archiveFile = "D:\Temp\Podcasts\downloaded.csv"


# Create the directory if it doesn't already exist

function Get-UrlHash {
  param(
    [string]$Url
  )
  $urlBase = $Url -replace '\?.*$', ''
  $urlHashBin = [System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($urlBase))
  $urlHash = [System.BitConverter]::ToString($urlHashBin).Replace('-', '').ToLower()
  return $urlHash  
}

function Check-ArchiveFile {
  param(
    [string]$ArchiveFile,
    [string]$Url
  )
  ### Format:
  # UrlHash,Title

  if (!(Test-Path $ArchiveFile)) {
    return $false
  }

  $archive = Get-Content $ArchiveFile | ConvertFrom-Csv

  return $archive.UrlHash -contains $(Get-UrlHash($Url))
}

function Record-ArchiveFile {
  param(
    [string]$ArchiveFile,
    [string]$Url,
    [string]$Title
  )
  
  if (!(Test-Path $ArchiveFile)) {
    New-Item -ItemType File -Path $ArchiveFile | Out-Null
    # Add CSV headers
    Add-Content $ArchiveFile "UrlHash,Title"
  }

  $urlHash = Get-UrlHash($Url)
  Add-Content $ArchiveFile "${urlHash},${Title}"
}

function Download-RssFeed {
  param(
    [string]$Url,
    [string]$Directory,
    [string]$ArchiveFile
  )

  if (!(Test-Path $directory)) {
    New-Item -ItemType Directory -Path $directory | Out-Null
  }
  
  $client = New-Object System.Net.WebClient
  
  # Download the RSS feed and parse it as XML
  [xml]$rss = $client.DownloadString($url)

  # Loop through each item in the RSS feed
  foreach ($item in $rss.rss.channel.item) {

    $mp3Url = $item.enclosure.url
    $title = $item.title[0]

    # Check if the episode is already downloaded
    $isArchive = Check-ArchiveFile -ArchiveFile $archiveFile -Url $mp3Url
    if ($isArchive) {
      Write-Debug "$title is already downloaded, skipping."
      Continue
    }

    $filename = "$($item.episode). $title.mp3.part" -replace '[\\/:*?"<>|]', '' # Remove the special characters

    Write-Debug "Downloading $mp3Url..."
    Write-Debug "Title: $title"

    $filepath = "$directory\$filename"
    $client.DownloadFile($mp3Url, $filepath)

    # Check if download was successful
    if ($client.ResponseHeaders['Content-Length'] -eq (Get-Item $filepath).Length) {
      # Rename the file to remove the .part extension
      Rename-Item -Path $filepath -NewName ($filepath -replace '\.part$', '') -Force | Out-Null
      Write-Debug "COMPLETED: $title"
      Record-ArchiveFile -ArchiveFile $archiveFile -Url $mp3Url -Title $title
    }
    else {
      Write-Error "Download failed for $title"
    }
  }
}

