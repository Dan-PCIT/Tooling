# PC-IT Support - OSDCloud v2 zero-touch deploy script
# Hosted at a raw URL and fetched by WinPE at boot, so changes here apply
# to every device booted afterwards without rebuilding the USB.

# ---- Settings (edit these to change what gets deployed) ----
$WinOS      = 'Windows 11 25H2'   # Must exist in the OSDCloud operating system catalog
$WinEdition = 'Pro'
# ------------------------------------------------------------

Write-Host -ForegroundColor Green "Starting OSDCloud ZTI"
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

# ---- Post-deploy: NinjaOne agent ----
# OSDCloud v2 does not apply a provisioning package from Automate\Provisioning,
# so copy the Ninja MSI from the USB and install it silently at the end of Windows setup
# using SetupComplete.cmd (runs as SYSTEM before first sign-in).
if (Test-Path 'C:\Windows\System32') {
    $NinjaSource = $null
    $NinjaRelativePaths = @('PCIT\NinjaOne-Agent.msi', 'OSDCloud\Automate\Provisioning\NinjaOne-Agent.msi')
    :search foreach ($Volume in (Get-Volume | Where-Object { $_.DriveLetter })) {
        foreach ($RelativePath in $NinjaRelativePaths) {
            $Candidate = "$($Volume.DriveLetter):\$RelativePath"
            if (Test-Path $Candidate) { $NinjaSource = $Candidate; break search }
        }
    }

    if ($NinjaSource) {
        $ScriptsPath = 'C:\Windows\Setup\Scripts'
        New-Item -Path $ScriptsPath -ItemType Directory -Force | Out-Null
        Copy-Item -Path $NinjaSource -Destination "$ScriptsPath\NinjaOne-Agent.msi" -Force

        $SetupComplete = @'
@echo off
echo %date% %time% SetupComplete start>>C:\Windows\Temp\pcit-setupcomplete.log
msiexec /i "C:\Windows\Setup\Scripts\NinjaOne-Agent.msi" /qn /norestart /l*v C:\Windows\Temp\pcit-ninja-install.log
echo %date% %time% msiexec exit code %errorlevel%>>C:\Windows\Temp\pcit-setupcomplete.log
if %errorlevel% EQU 0 del /f /q "C:\Windows\Setup\Scripts\NinjaOne-Agent.msi"
'@
        $SetupComplete | Out-File -FilePath "$ScriptsPath\SetupComplete.cmd" -Encoding ascii -Force
        Write-Host -ForegroundColor Green "NinjaOne agent staged from $NinjaSource"
    }
    else {
        Write-Warning "NinjaOne-Agent.msi not found on any volume. The agent will not be installed."
    }
}

# Restart from WinPE
Write-Host -ForegroundColor Green "Restarting in 20 seconds!"
Start-Sleep -Seconds 20
wpeutil reboot
