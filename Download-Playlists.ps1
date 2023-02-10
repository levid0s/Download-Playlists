param(
	[Parameter(Mandatory)][string]$YamlFile
)

function Install-ModuleIfNotPresent {
	param(
		[string]$ModuleName
	)

	if (!(get-module $ModuleName -ListAvailable -ErrorAction SilentlyContinue)) {
		Install-Module $ModuleName -Scope CurrentUser
	}
}

Install-ModuleIfNotPresent 'PowerShell-YAML'


$timestamp = `Get-Date -Format 'yyyyMMdd-HHmmss'` 
$archiveFileName = '_downloaded.txt'

# $yamlFile = "AndrejKarpathy.yaml"
$Yaml = Get-Content $YamlFile -Raw | ConvertFrom-Yaml | Select-Object -First 1

$NamingStyles = @{
	"playlist/date-title"  = "%(playlist)s/%(upload_date)s - %(title)s.%(ext)s"
	"playlist/index-title" = "%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s"
	"playlist/default"     = "%(playlist)s/%(title)s-%(id)s.%(ext)s"
	"default"              = "%(title)s-%(id)s.%(ext)s"
	"root/index-title"     = "%(playlist_index)s - %(title)s.%(ext)s"	
}

# Test yt-dlp
$dlcmd = "yt-dlp"
try {
	Write-Debug "Checking for ${dlcmd}.."
	&${dlcmd} 2>$NULL
	Write-Debug "${dlcmd} found."
}
catch {
	Write-Debug "${dlcmd} not found in %PATH%. Trying youtube-dl.."
	$dlcmd = $null
}

if (!$dlcmd) {
	# Test Youtube-DL
	$dlcmd = "youtube-dl"
	try {
		Write-Debug "Checking for youtube-dl.."
		&youtube-dl 2>$NULL
		Write-Debug "youtube-dl found."
	}
	catch {
		$Raise_Error = "ERROR: Youtube-dl not found in %PATH%"; Throw $Raise_Error
	}
}

# Test FFMPEG
try {
	Write-Debug "Checking for ffmpeg.."
	&ffmpeg 2>$NULL
	Write-Debug "ffmpeg found."
}
catch {
	Write-Warning "WARNING: FFMPEG not found in %PATH%. Some features might not be available. Press ENTER to continue.."
	Read-Host | Out-Null
}

foreach ($obj in $Yaml) {
	Write-Debug "Processing: $($obj.folder)"

	$folder = "${PSScriptRoot}\$($obj.folder)"
	Write-Debug "Using folder: $folder"

	if (!(Test-Path $folder)) {
		New-Item -ItemType Directory -Path $folder -Force -Verbose
	}
	
	Push-Location $folder
	$archiveFile = "$folder\$archiveFileName"
	$archiveOld = "$folder\_downloaded_old\"
	foreach ($playlist in $obj.Playlists) {
		Write-Debug "Processing playlist: $($playlist.name)"
		# Backup old archive file
		if (Test-Path  $archiveFile) {
			if (!(Test-Path -PathType Container $archiveOld)) {
				New-Item -ItemType Directory -Path $archiveOld -Force -Verbose
			}
			Copy-Item $archiveFile "$archiveOld/$((Get-Item $archiveFile).BaseName)-$timestamp$((Get-Item $archiveFile).Extension)" -Verbose
		}
	
		if (!$playlist.naming) {
			$playlist.naming = 'playlist/default'
		}
	
		$Options = @(
			'-v',
			'-ciw',
			'--download-archive', "`"$archiveFile`"",
			'-o', "`"$($NamingStyles[$playlist.naming])`""
			'--add-metadata'
		)
	
		if ($playlist.naming) {
			$Options += @(
			)
		}
		else {
			$Options += @(
				'-o', "`"$($NamingStyles['playlist/default'])`""
			)
		}
	
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
	}
	
	Pop-Location
}

Write-Debug "Done."
