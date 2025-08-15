# Minecraft Bedrock Server World Backup Script
# Automatically detects the most recent server version and backs up world files

# ===== CONFIGURATION =====
# Set these paths according to your setup
$ServerRootDirectory = "C:\MinecraftServer"  # Directory containing bedrock-server-x.xx.xx folders
$BackupDirectory = "C:\MinecraftBackups"     # Where to store backups
$LogFile = "C:\MinecraftBackups\backup.log" # Log file location

# ===== SCRIPT START =====
$ErrorActionPreference = "Stop"
$Date = Get-Date -Format "yyyy-MM-dd"

# Function to write log messages
function Write-Log {
    param([string]$Message)
    $LogMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogFile -Value $LogMessage
}

try {
    Write-Log "Starting Minecraft Bedrock server backup..."
    
    # Ensure backup directory exists
    if (!(Test-Path -Path $BackupDirectory)) {
        New-Item -ItemType Directory -Path $BackupDirectory -Force
        Write-Log "Created backup directory: $BackupDirectory"
    }
    
    # Ensure log file directory exists
    $LogDir = Split-Path -Path $LogFile -Parent
    if (!(Test-Path -Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force
    }
    
    # Find the most recently modified bedrock-server directory
    Write-Log "Searching for bedrock server directories in: $ServerRootDirectory"
    
    $ServerDirectories = Get-ChildItem -Path $ServerRootDirectory -Directory | 
                        Where-Object { $_.Name -match "^bedrock-server-\d+\.\d+\.\d+" } |
                        Sort-Object LastWriteTime -Descending
    
    if ($ServerDirectories.Count -eq 0) {
        throw "No bedrock-server directories found in $ServerRootDirectory"
    }
    
    $LatestServerDir = $ServerDirectories[0]
    Write-Log "Found latest server directory: $($LatestServerDir.Name) (Last modified: $($LatestServerDir.LastWriteTime))"
    
    # Check if worlds directory exists
    $WorldsPath = Join-Path -Path $LatestServerDir.FullName -ChildPath "worlds"
    if (!(Test-Path -Path $WorldsPath)) {
        throw "Worlds directory not found at: $WorldsPath"
    }
    
    Write-Log "Found worlds directory: $WorldsPath"
    
    # Get all items in the worlds directory
    $WorldItems = Get-ChildItem -Path $WorldsPath
    
    if ($WorldItems.Count -eq 0) {
        Write-Log "Warning: No world files found in worlds directory"
        return
    }
    
    Write-Log "Found $($WorldItems.Count) items in worlds directory"
    
    # Create backup subdirectory for this date
    $BackupSubDir = Join-Path -Path $BackupDirectory -ChildPath "backup_$Date"
    New-Item -ItemType Directory -Path $BackupSubDir -Force | Out-Null
    
    # Copy each item from worlds directory
    foreach ($Item in $WorldItems) {
        $SourcePath = $Item.FullName
        
        if ($Item.PSIsContainer) {
            # It's a directory - copy the entire folder
            $DestPath = Join-Path -Path $BackupSubDir -ChildPath "$($Item.Name)_$Date"
            Copy-Item -Path $SourcePath -Destination $DestPath -Recurse -Force
            Write-Log "Backed up world folder: $($Item.Name) -> $($Item.Name)_$Date"
        } else {
            # It's a file - copy with date appended to filename
            $FileExtension = [System.IO.Path]::GetExtension($Item.Name)
            $FileNameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($Item.Name)
            $NewFileName = "$FileNameWithoutExt`_$Date$FileExtension"
            $DestPath = Join-Path -Path $BackupSubDir -ChildPath $NewFileName
            
            Copy-Item -Path $SourcePath -Destination $DestPath -Force
            Write-Log "Backed up world file: $($Item.Name) -> $NewFileName"
        }
    }
    
    # Calculate backup size
    $BackupSize = (Get-ChildItem -Path $BackupSubDir -Recurse | Measure-Object -Property Length -Sum).Sum
    $BackupSizeMB = [math]::Round($BackupSize / 1MB, 2)
    
    Write-Log "Backup completed successfully!"
    Write-Log "Backup location: $BackupSubDir"
    Write-Log "Backup size: $BackupSizeMB MB"
    
    # Optional: Clean up old backups (uncomment and modify as needed)
    # Keep only the last 30 days of backups
    <#
    $CutoffDate = (Get-Date).AddDays(-30)
    $OldBackups = Get-ChildItem -Path $BackupDirectory -Directory | 
                  Where-Object { $_.Name -match "^backup_\d{4}-\d{2}-\d{2}$" -and $_.CreationTime -lt $CutoffDate }
    
    foreach ($OldBackup in $OldBackups) {
        Remove-Item -Path $OldBackup.FullName -Recurse -Force
        Write-Log "Removed old backup: $($OldBackup.Name)"
    }
    #>
    
} catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log "Backup failed!"
    exit 1
}

Write-Log "Backup script completed."