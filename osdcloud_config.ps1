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

# Restart from WinPE
Write-Host -ForegroundColor Green "Restarting in 20 seconds!"
Start-Sleep -Seconds 20
wpeutil reboot
