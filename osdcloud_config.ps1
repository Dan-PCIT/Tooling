# PC-IT Support - OSDCloud v2 zero-touch deploy script
# Hosted at a raw URL and fetched by WinPE at boot, so changes here apply
# to every device booted afterwards without rebuilding the USB.

# ---- Settings (edit these to change what gets deployed) ----
$WinOS      = 'Windows 11 25H2'   # Must exist in the OSDCloud operating system catalog
$WinEdition = 'Pro'
# ------------------------------------------------------------

Write-Host -ForegroundColor Green "Starting OSDCloud PCIT Support"
Write-Host -ForegroundColor DarkGray "Operating System: $WinOS | Edition: $WinEdition"
Start-Sleep -Seconds 5

# -CLI runs the default workflow without the GUI
Deploy-OSDCloud -CLI -OperatingSystem $WinOS -OSEdition $WinEdition

# ---- Post-deploy: place unattend.xml ----
# The file stays on the USB (\PCIT\unattend.xml on any volume), NOT in this repo,
# because it contains the local admin password.
if (Test-Path 'C:\Windows\System32') {
    $UnattendSource = $null
    foreach ($Volume in (Get-Volume | Where-Object { $_.DriveLetter })) {
        $Candidate = "$($Volume.DriveLetter):\PCIT\unattend.xml"
        if (Test-Path $Candidate) { $UnattendSource = $Candidate; break }
    }

    if ($UnattendSource) {
        New-Item -Path 'C:\Windows\Panther' -ItemType Directory -Force | Out-Null
        Copy-Item -Path $UnattendSource -Destination 'C:\Windows\Panther\Unattend.xml' -Force
        Write-Host -ForegroundColor Green "Unattend copied from $UnattendSource"
    }
    else {
        Write-Warning "unattend.xml not found under \PCIT\ on any volume. Windows will show OOBE."
    }
}
else {
    Write-Warning "Windows not found on C: - skipping unattend copy."
}

# Restart from WinPE
Write-Host -ForegroundColor Green "Restarting in 20 seconds!"
Start-Sleep -Seconds 20
wpeutil reboot
