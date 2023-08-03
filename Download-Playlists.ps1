param(
  [string]$YamlFile,
  [string]$DlCmd = 'yt-dlp'
)

# function IsRunningAsScript {
# 	$shellNames = @('cmd', 'powershell', 'ConEmuC', 'ConEmuC64')
# 	$parentPID = (Get-WmiObject Win32_Process -Filter "ProcessId=$($PID)").ParentProcessId
# 	$parentName = (Get-Process -Id $ParentPID).Name

# 	return ($parentName -in $shellNames)
# }

# function PauseIfNotScript {
# 	if (!(IsRunningAsScript)) {
# 		Read-Host 'Press ENTER to continue' | Out-Null
# 	}
# }

$ScriptRoot = $PSScriptRoot
if (!$ScriptRoot) {
  $ScriptRoot = 'N:/Videos'
}

. "${ScriptRoot}/../src/useful/ps-winhelpers/_PS-WinHelpers.ps1"

if (!$YamlFile) {
  $YamlFile = Invoke-FilePicker -Path "$ScriptRoot/_defs" -Filter 'Yaml files (*.ya?ml)|*.yaml;*.yml'
}

Install-ModuleIfNotPresent 'PowerShell-YAML'


$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$archiveFileName = '_downloaded.txt'
$tempPath = "$ScriptRoot\~dl_tmp"

$Yaml = Get-Content $YamlFile -Raw | ConvertFrom-Yaml
$Playlists = $Yaml.Playlists

$NamingStyles = @{
  'playlist/date-title'  = '%(playlist)s/%(upload_date)s - %(title)s.%(ext)s'
  'playlist/index-title' = '%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s'
  'playlist/default'     = '%(playlist)s/%(title)s-%(id)s.%(ext)s' # Default
  'root/default'         = '%(title)s-%(id)s.%(ext)s'
  'default'              = '%(title)s-%(id)s.%(ext)s'
  'root/date-title'      = '%(upload_date)s - %(title)s.%(ext)s'
  'root/index-title'     = '%(playlist_index)s - %(title)s.%(ext)s'
  'root/channel-title'   = '%(channel)s - %(title)s.%(ext)s'
}

####
#Region Preflight checks
####

if ($DlCmd) {
  if (!(Get-Command -Name $DlCmd -ErrorAction SilentlyContinue)) {
    $Raise_Error = "ERROR: $DlCmd not found in %PATH%"; Throw $Raise_Error
  }
}
else {
  # Test yt-dlp
  if (Get-Command -Name 'yt-dlp' -ErrorAction SilentlyContinue) {
    $DlCmd = 'yt-dlp'
  }
  elseif (Get-Command -Name 'youtube-dl' -ErrorAction SilentlyContinue) {
    $DlCmd = 'youtube-dl'
  }
  else {
    $Raise_Error = "ERROR: Neither `yt-dlp` nor `youtube-dl` found in %PATH%"; Throw $Raise_Error
  }
}

Write-Debug "Starting $dlcmd empty to have the binary cached."
&$DlCmd --version | Out-Null

# Test FFMPEG
if (!(Get-Command -Name 'ffmpeg' -ErrorAction SilentlyContinue)) {
  Write-Warning 'WARNING: FFMPEG not found in %PATH%. Some features might not be available. Press ENTER to continue..'
  Read-Host | Out-Null
}
else {
  &ffmpeg -version | Out-Null
}

if (!(Get-Command -Name pssuspend -ErrorAction SilentlyContinue)) {
  Write-Warning 'Sysinternals'' PSSuspend not found. We won''t be able to suspend the dropbox sync. Press ENTER to carry on.'
  Read-Host | Out-Null
}
&pssuspend -nobanner | Out-Null

#######
#Region  Set up staging area
#######

if (!(Test-Path $tempPath)) {
  New-Item -ItemType Directory -Path $TempPath -ErrorAction Stop | Out-Null
}

Set-DropboxIgnoredPath -Path $tempPath

#######
#Endregion
#######


###
###  Processing Youtube-DL playlists
###

foreach ($playlist in $Playlists) {
  if ($playlist.stepTitle) {
    $step = $playlist.stepTitle
  }
  else {
    $step = $playlist.url
  }

  Write-Verbose ">>> [PROCESSING]: $step"
  Write-Verbose ">>> [OutPath]: $outPath"

  $outPath = $playlist.outPath

  if (!(Test-Path $outPath)) {
    New-Item -ItemType Directory -Path $outPath -Force -Verbose -ErrorAction Stop
  }
	
  # Backup archive file
  $archivePath = "$outPath\$archiveFileName"
  $archiveFileBase = $archiveFileName -replace '\.[^.]+$', ''
  $archiveFileExt = $archiveFileName -replace '^.*\.', ''
  $archiveBackupDir = "$outPath\_downloaded_old\"
  $archiveBackupPath = "${archiveBackupDir}/${archiveFileBase}-${timestamp}.${archiveFileExt}"

  if (Test-Path $archivePath) {
    if (!(Test-Path -PathType Container $archiveBackupDir)) {
      New-Item -ItemType Directory -Path $archiveBackupDir -Force
    }
    Copy-Item $archivePath $archiveBackupPath -Verbose
  }
	
  if (!$playlist.naming) {
    # Default playlist naming style
    $playlist.naming = 'playlist/default'
  }

  if (!($NamingStyles[$playlist.naming])) {
    $Raise_Error = "ERROR: Invalid naming style: $($playlist.naming)"; Throw $Raise_Error
  }
	
  # Default options
  # '-v',
	
  $Options = @(

    '-ciw',
    '--download-archive', "`"$archivePath`"",
    '-P', "`"$outPath`"",
    '-P', "temp:`"$tempPath`"",
    '-o', "`"$($NamingStyles[$playlist.naming])`""
    '--add-metadata'
  )
	
  if ($playlist.options) {
    $playlist.options.GetEnumerator() | ForEach-Object { $Options += "--$($_.Name)"; $Options += "$($_.Value)" }
  }
	
  $Options = $Options | Where-Object { $_ } # Remove empty elements from array
  $Options += $playlist.url
	
  Write-Debug 'Suspending Dropbox..'
  Start-Process pssuspend -ArgumentList '-nobanner', 'dropbox' -NoNewWindow -Wait

  Write-Debug "Starting: $dlcmd $($Options -join ' ') "
	
  $process = Start-Process -FilePath $dlcmd -ArgumentList $Options -NoNewWindow -PassThru -Wait

  Write-Debug 'Resuming Dropbox..'
  Start-Process pssuspend -ArgumentList '-nobanner', '-r', 'dropbox' -NoNewWindow -Wait

  if ($process.ExitCode -ne 0) {
    Write-Error "Process exited with $($process.ExitCode)"
    Start-Sleep 5
  }

  $aOldHash = Get-FileHash $archiveBackupPath -Algorithm SHA256
  $aNewHash = Get-FileHash $archivePath -Algorithm SHA256
  if ($aOldHash.Hash -eq $aNewHash.Hash) {
    Write-Verbose 'Archive file unchanged. Removing backup archive file..'
    Remove-Item $archiveBackupPath -Force -Verbose
  }

  ###
  ###  Sync
  ###

  if ($playlist.sync -eq $true ) {
    $syncDrive = Get-SyncDevice $playlist.syncToDevice
    $syncPath = "${syncDrive}$($playlist.syncRoot)"

    Invoke-FileSync -Source $outPath -Destination $syncPath
  }
}

Write-Debug 'Download complete.'
