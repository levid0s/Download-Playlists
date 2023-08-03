function Get-YtVideoStatus {
  param(
    [string]$videoId
  )
    
  $output = yt-dlp --no-warnings --skip-download --flat-playlist "https://www.youtube.com/watch?v=$videoId" -j
  if ($LASTEXITCODE -ne 0) {
    Throw "Failed to get video info for $videoId"
  }
  $videoInfo = $output | ConvertFrom-Json
  $status = $videoInfo.availability

  return $status
}

function UpdateFile {
  param(
    [string]$file,
    [string]$videoId,
    [string]$status
  )

  $content = Get-Content $file
  $content = $content -replace "$videoId.*", "$videoId $status"
  Set-Content $file $content
}


function Scan-Videos {
  <# 
  .SYNOPSIS
  Scans a youtube-dl archive file (text file with a list of video ids) and checks their status -
  Checks if any videos have been removed or marked private
  #>
  
  param(
    [string]$ArchiveFilePath
  )

  $videos = Get-Content $ArchiveFilePath

  foreach ($v in $videos) {
    $null, $vid, $status = $v -split ' '

    if ([string]::IsNullOrEmpty($vid)) {
      continue
    }

    if (!([string]::IsNullOrEmpty($status))) {
      continue
    }

    $status = Get-YtVideoStatus $vid
    Write-Debug "Dected video status: $vid $status"
    # Read-Host | Out-Null
    UpdateFile $ArchiveFilePath $vid $status
    Start-Sleep -Milliseconds 100
  }
}
