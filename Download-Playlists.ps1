param(
	[Parameter(Mandatory)][string]$YamlFile,
	[string]$DlCmd = 'yt-dlp'
)

function Install-ModuleIfNotPresent {
	param(
		[string]$ModuleName
	)

	if (!(get-module $ModuleName -ListAvailable -ErrorAction SilentlyContinue)) {
		Install-Module $ModuleName -Scope CurrentUser
	}
}

function Test-CommandExists {
	param(
		[string]$cmd
	)

	try {
		Write-Debug "Checking for ${cmd}.."
		&${cmd} 2>$NULL
		Write-Debug "${cmd} found."
		return $true
	}
	catch {
		Write-Debug "${cmd} not found in %PATH%.."
		return $false
	}
}


Install-ModuleIfNotPresent 'PowerShell-YAML'


$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$archiveFileName = '_downloaded.txt'

$Yaml = Get-Content $YamlFile -Raw | ConvertFrom-Yaml
$Playlists = $Yaml.Playlists

$NamingStyles = @{
	"playlist/date-title" = "%(playlist)s/%(upload_date)s - %(title)s.%(ext)s"
	"root/st/index-title" = "%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s"
	"playlist/default"    = "%(playlist)s/%(title)s-%(id)s.%(ext)s" # Default
	"default"             = "%(title)s-%(id)s.%(ext)s"
	"root/index-title"    = "%(playlist_index)s - %(title)s.%(ext)s"
	"root/channel-title"  = "%(channel)s - %(title)s.%(ext)s"
}

if ($DlCmd) {
	if (!(Test-CommandExists $DlCmd)) {
		$Raise_Error = "ERROR: $DlCmd not found in %PATH%"; Throw $Raise_Error
	}
}
else {
	# Test yt-dlp
	if (Test-CommandExists "yt-dlp") {
		$DlCmd = "yt-dlp"
	}
	elseif (Test-CommandExists "youtube-dl") {
		$DlCmd = "youtube-dl"
	}
	else {
		$Raise_Error = "ERROR: Neither `yt-dlp` nor `youtube-dl` found in %PATH%"; Throw $Raise_Error
	}
}

# Test FFMPEG
if (!(Test-CommandExists "ffmpeg")) {
	Write-Warning "WARNING: FFMPEG not found in %PATH%. Some features might not be available. Press ENTER to continue.."
	Read-Host | Out-Null
}

foreach ($playlist in $Playlists) {
	if ($playlist.stepTitle) {
		$step = $playlist.stepTitle
	}
	else {
		$step = $playlist.url
	}

	Write-Debug "Processing: $step"

	$outPath = $playlist.outPath
	Write-Debug "OutPath: $outPath"

	Continue
	if (!(Test-Path $outPath)) {
		New-Item -ItemType Directory -Path $outPath -Force -Verbose
	}
	
	Push-Location $outPath
	$archiveFile = "$outPath\$archiveFileName"
	$archiveOldDir = "$folder\_downloaded_old\"
	$archiveOldFile = "$archiveOldDir/$((Get-Item $archiveFile).BaseName)-$timestamp$((Get-Item $archiveFile).Extension)"

	if (Test-Path  $archiveFile) {
		if (!(Test-Path -PathType Container $archiveOldDir)) {
			New-Item -ItemType Directory -Path $archiveOldDir -Force -Verbose
		}
		Copy-Item $archiveFile $archiveOldFile -Verbose
	}
	
	if (!$playlist.naming) {
		# Default playlist naming style
		$playlist.naming = 'playlist/default'
	}
	
	# Default options
	$Options = @(
		'-v',
		'-ciw',
		'--download-archive', "`"$archiveFile`"",
		'-o', "`"$($NamingStyles[$playlist.naming])`""
		'--add-metadata'
	)
	
	if ($playlist.options) {
		$playlist.options.GetEnumerator() | ForEach-Object { $Options += "--$($_.Name)"; $Options += "$($_.Value)" }
	}
	
	$Options = $Options |  Where-Object { $_ } # Remove empty elements from array
	$Options += $playlist.url
	
	Write-Debug "Starting: $dlcmd $($Options -join ' ') "
	
	$process = Start-Process -FilePath $dlcmd -ArgumentList $Options -NoNewWindow -PassThru -Wait
	if ($process.ExitCode -ne 0) {
		Write-Error "Process exited with $($process.ExitCode)"
		Start-Sleep 5
	}

	$aOldHash = Get-FileHash $archiveOldFile -Algorithm SHA256
	$aNewHash = Get-FileHash $archiveFile -Algorithm SHA256
	if ($aOldHash.Hash -eq $aNewHash.Hash) {
		Write-Debug "Archive file unchanged. Removing backup archive file.."
		Remove-Item $archiveOldFile -Force -Verbose
	}

	Pop-Location
}

WPop-Location
r

W

WPop-Location
r

W

WPop-Location
r

WPite-Debug "Done, all playlist entries processed."ite-Debug "Done, all playlist entries processed."rite-Debug "Done, all playlist entries processed."op-Location
r

Write-Debug "Done, all playlist entries processed."ite-Debug "Done, all playlist entries processed."rite-Debug "Done, all playlist entries processed."ite-Debug "Done, all playlist entries processed."

# Test FFMPEG
if (!(Test-CommandExists "ffmpeg")) {
	Write-Warning "WARNING: FFMPEG not found in %PATH%. Some features might not be available. Press ENTER to continue.."
	Read-Host | Out-Null
}

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

	Write-Debug ">>> [PROCESSING]: $step"
	Write-Debug ">>> [OutPath]: $outPath"

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

	if (Test-Path  $archivePath) {
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
	$Options = @(
		'-v',
		'-ciw',
		'--download-archive', "`"$archivePath`"",
		'-o', "`"${outPath}/$($NamingStyles[$playlist.naming])`""
		'--add-metadata'
	)
	
	if ($playlist.options) {
		$playlist.options.GetEnumerator() | ForEach-Object { $Options += "--$($_.Name)"; $Options += "$($_.Value)" }
	}
	
	$Options = $Options |  Where-Object { $_ } # Remove empty elements from array
	$Options += $playlist.url
	
	Write-Debug "Starting: $dlcmd $($Options -join ' ') "
	
	$process = Start-Process -FilePath $dlcmd -ArgumentList $Options -NoNewWindow -PassThru -Wait
	if ($process.ExitCode -ne 0) {
		Write-Error "Process exited with $($process.ExitCode)"
		Start-Sleep 5
	}

	$aOldHash = Get-FileHash $archiveBackupPath -Algorithm SHA256
	$aNewHash = Get-FileHash $archivePath -Algorithm SHA256
	if ($aOldHash.Hash -eq $aNewHash.Hash) {
		Write-Debug "Archive file unchanged. Removing backup archive file.."
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
Write-Debug "Done, all playlist entries processed."

$RssFeeds = $Yaml.RssFeeds

foreach ($rss in $RssFeeds) {
	
}
