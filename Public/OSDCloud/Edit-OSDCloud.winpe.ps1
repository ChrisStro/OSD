<#
.SYNOPSIS
Edits the boot.wim in an OSDCloud.workspace

.Description
Edits the boot.wim in an OSDCloud.workspace

.PARAMETER WorkspacePath
Directory for the OSDCloud.workspace which contains Media directory
This is optional as the OSDCloud.workspace is returned by Get-OSDCloud.workspace automatically

.PARAMETER DriverPath
Path to additional Drivers you want to install

.PARAMETER CloudDriver
Download and install in WinPE drivers from Dell,HP,Nutanix,VMware,WiFi

.LINK
https://osdcloud.osdeploy.com

.NOTES
#>
function Edit-OSDCloud.winpe {
    [CmdletBinding(PositionalBinding = $false)]
    param (
        [ValidateSet('*','Dell','HP','IntelNet','LenovoDock','Nutanix','USB','VMware','WiFi')]
        [string[]]$CloudDriver,
        [string[]]$DriverHWID,
        [string[]]$DriverPath,

        [string[]]$PSModuleCopy,
        [Alias('Modules')]
        [string[]]$PSModuleInstall,

        [string]$Startnet,
        [string]$StartOSDCloud,
        [switch]$StartOSDCloudGUI,
        [string]$StartOSDPad,
        [string]$StartPSCommand,
        [Alias('WebPSScript')]
        [string]$StartWebScript,
        [switch]$UpdateUsb,
        [string]$Wallpaper,
        [string]$WorkspacePath
    )
    #=================================================
    #	Start the Clock
    #=================================================
    $WinpeStartTime = Get-Date
    #=================================================
    #	Block
    #=================================================
    Block-WinPE
    Block-StandardUser
    Block-WindowsVersionNe10
    Block-PowerShellVersionLt5
    Block-NoCurl
    #=================================================
    #	Get-OSDCloud.template
    #=================================================
    if (-NOT (Get-OSDCloud.template)) {
        Write-Warning "Setting up a new OSDCloud.template"
        New-OSDCloud.template -Verbose
    }

    $OSDCloudTemplate = Get-OSDCloud.template
    if (-NOT ($OSDCloudTemplate)) {
        Write-Warning "Something bad happened.  I have to go"
        Break
    }
    #=================================================
    #	Set WorkspacePath
    #=================================================
    if ($PSBoundParameters.ContainsKey('WorkspacePath')) {
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Setting Workspace Path"
        Set-OSDCloud.workspace -WorkspacePath $WorkspacePath -ErrorAction Stop | Out-Null
    }
    $WorkspacePath = Get-OSDCloud.workspace
    #=================================================
    #	Setup Workspace
    #=================================================
    if (-NOT ($WorkspacePath)) {
        Write-Warning "You need to provide a path to your Workspace with one of the following examples"
        Write-Warning "New-OSDCloud.iso -WorkspacePath C:\OSDCloud"
        Write-Warning "New-OSDCloud.workspace -WorkspacePath C:\OSDCloud"
        Break
    }

    if (-NOT (Test-Path $WorkspacePath)) {
        New-OSDCloud.workspace -WorkspacePath $WorkspacePath -Verbose -ErrorAction Stop
    }

    if (-NOT (Test-Path "$WorkspacePath\Media")) {
        New-OSDCloud.workspace -WorkspacePath $WorkspacePath -Verbose -ErrorAction Stop
    }

    if (-NOT (Test-Path "$WorkspacePath\Media\sources\boot.wim")) {
        Write-Warning "Nothing is going well for you today my friend"
        Break
    }
    #=================================================
    #	Remove Old Autopilot Content
    #=================================================
    if (Test-Path "$env:ProgramData\OSDCloud\Autopilot") {
        Write-Warning "Move all your Autopilot Profiles to $env:ProgramData\OSDCloud\Config\AutopilotJSON"
        Write-Warning "You will be unable to create or update an OSDCloud Workspace until $env:ProgramData\OSDCloud\Autopilot is manually removed"
        Break
    }
    if (Test-Path "$WorkspacePath\Autopilot") {
        Write-Warning "Move all your Autopilot Profiles to $WorkspacePath\Config\AutopilotJSON"
        Write-Warning "You will be unable to create or update an OSDCloud Workspace until $WorkspacePath\Autopilot is manually removed"
        Break
    }
    #=================================================
    #   Mount-MyWindowsImage
    #=================================================
    $MountMyWindowsImage = Mount-MyWindowsImage -ImagePath "$WorkspacePath\Media\Sources\boot.wim"
    $MountPath = $MountMyWindowsImage.Path
    #=================================================
    #   Robocopy Config
    #=================================================
    if (Test-Path "$WorkspacePath\Config") {
        robocopy "$WorkspacePath\Config" "$MountPath\OSDCloud\Config" *.* /mir /ndl /njh /njs /b /np
    }
    #=================================================
    #   Robocopy ODT Config
    #=================================================
    if (Test-Path "$WorkspacePath\ODT") {
        robocopy "$WorkspacePath\ODT" "$MountPath\OSDCloud\ODT" *.xml /mir /ndl /njh /njs /b /np
        robocopy "$WorkspacePath\ODT" "$MountPath\OSDCloud\ODT" setup.exe /mir /ndl /njh /njs /b /np
    }
    #=================================================
    #   DriverHWID
    #=================================================
    if ($DriverHWID) {
        $AddWindowsDriverPath = Join-Path $env:TEMP (Get-Random)
        foreach ($Item in $DriverHWID) {
            Save-MsUpCatDriver -HardwareID $Item -DestinationDirectory $AddWindowsDriverPath
        }
        try {
            Add-WindowsDriver -Path "$($MountMyWindowsImage.Path)" -Driver $AddWindowsDriverPath -Recurse -ForceUnsigned -Verbose | Out-Null
        }
        catch {
            Write-Warning "Unable to find a driver for $Item"
        }
    }
    #=================================================
    #   CloudDriver
    #=================================================
    if ($CloudDriver) {
        foreach ($Driver in $CloudDriver) {
            $AddWindowsDriverPath = Save-WinPECloudDriver -CloudDriver $Driver -Path (Join-Path $env:TEMP (Get-Random))
            Add-WindowsDriver -Path "$($MountMyWindowsImage.Path)" -Driver "$AddWindowsDriverPath" -Recurse -ForceUnsigned -Verbose | Out-Null
        }
        $null = Save-WindowsImage -Path $MountPath
    }
    #=================================================
    #   DriverPath
    #=================================================
    foreach ($AddWindowsDriverPath in $DriverPath) {
        Add-WindowsDriver -Path "$($MountMyWindowsImage.Path)" -Driver "$AddWindowsDriverPath" -Recurse -ForceUnsigned -Verbose
    }
    #=================================================
    #   Drop initial Startnet.cmd
    #=================================================
    $OSDVersion = (Get-Module -Name OSD -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
    Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Startnet.cmd: wpeinit"
$StartnetCMD = @"
@ECHO OFF
ECHO OSD $OSDVersion
ECHO Initialize WinPE
wpeinit
cd\
ECHO Initialize Hardware
start /wait PowerShell -Nol -W Mi -C Start-Sleep -Seconds 10
"@
    $StartnetCMD | Out-File -FilePath "$MountPath\Windows\System32\Startnet.cmd" -Encoding ascii -Width 2000 -Force
    #=================================================
    #   Wireless
    #=================================================
    if (Test-Path "$MountPath\Windows\WirelessConnect.exe") {
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Startnet.cmd: start PowerShell -NoL -C Start-WinREWiFi"
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value 'ECHO Initialize Wireless Network' -Force
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value 'start /wait PowerShell -NoL -C Start-WinREWiFi' -Force
    }
    #=================================================
    #   Network Delay, Start Update, PowerShell Minimized
    #=================================================
    Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value 'ECHO Initialize Network Connection (Minimized)' -Force
    Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value 'start /wait PowerShell -Nol -W Mi -C Start-Sleep -Seconds 10' -Force
    Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value 'ECHO Updating OSD PowerShell Module (Minimized)' -Force
    Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value 'start /wait PowerShell -NoL -W Mi -C "& {if (Test-WebConnection) {Install-Module OSD -Force -Verbose}}"'
    #Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value 'ECHO Installing Azure Modules for Accounts, KeyVault, and Storage (Minimized)' -Force
    #Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value 'start /wait PowerShell -NoL -W Mi -C "& {if (Test-WebConnection) {Install-Module Az.KeyVault,Az.Storage -Force -Verbose}}"'
    Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value 'ECHO Initialize PowerShell (Minimized)' -Force
    Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value 'start PowerShell -Nol -W Mi' -Force
    Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value '@ECHO ON' -Force
    #=================================================
    #   StartPSCommand Wait
    #=================================================
    if ($StartPSCommand) {
        Write-Warning "The StartPSCommand parameter is adding your Cloud PowerShell script to Startnet.cmd"
        Write-Warning "This must be set every time you run Edit-OSDCloud.winpe or it will revert back to defaults"

        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Startnet.cmd: start /wait PowerShell -NoL -C `"$StartPSCommand`""
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value "start /wait PowerShell -NoL -C `"$StartPSCommand`"" -Force
    }
    #=================================================
    #   StartWebScript /wait
    #=================================================
    if ($StartWebScript) {
        Write-Warning "The StartWebScript parameter is adding your Cloud PowerShell script to Startnet.cmd"
        Write-Warning "This must be set every time you run Edit-OSDCloud.winpe or it will revert back to defaults"

        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Startnet.cmd: start /wait PowerShell -NoL -C Invoke-WebPSScript '$StartWebScript'"
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value '@ECHO OFF' -Force
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value 'Invoke-WebPSScript' -Force
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value '@ECHO ON' -Force
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value "start /wait PowerShell -NoL -C Invoke-WebPSScript '$StartWebScript'" -Force
    }
    #=================================================
    #   StartOSDCloud /wait
    #=================================================
    if ($StartOSDCloud) {
        Write-Warning "The StartOSDCloud parameter is adding Start-OSDCloud to Startnet.cmd"
        Write-Warning "This must be set every time you run Edit-OSDCloud.winpe or it will revert back to defaults"
        
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Startnet.cmd: start /wait PowerShell -NoL -C Start-OSDCloud $StartOSDCloud"
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value '@ECHO OFF' -Force
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value 'ECHO Start-OSDCloud' -Force
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value "start /wait PowerShell -NoL -C Start-OSDCloud $StartOSDCloud"
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value '@ECHO ON' -Force
    }
    #=================================================
    #   StartOSDCloudGUI /wait
    #=================================================
    if ($StartOSDCloudGUI) {
        Write-Warning "The StartOSDCloudGUI parameter is adding Start-OSDCloudGUI to Startnet.cmd"
        Write-Warning "This must be set every time you run Edit-OSDCloud.winpe or it will revert back to defaults"
        
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Startnet.cmd: start /wait PowerShell -NoL -W Mi -C Start-OSDCloudGUI"
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value '@ECHO OFF' -Force
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value 'ECHO Start-OSDCloudGUI' -Force
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value 'start /wait PowerShell -NoL -W Mi -C Start-OSDCloudGUI'
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value '@ECHO ON' -Force
    }
    #=================================================
    #   StartOSDPad /wait
    #=================================================
    if ($StartOSDPad) {
        Write-Warning "The StartOSDPad parameter is adding OSDPad to Startnet.cmd"
        Write-Warning "This must be set every time you run Edit-OSDCloud.winpe or it will revert back to defaults"
        
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Startnet.cmd: start /wait PowerShell -NoL -C OSDPad $StartOSDPad"
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value '@ECHO OFF' -Force
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value 'ECHO OSDPad' -Force
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value '@ECHO ON' -Force
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value "start /wait PowerShell -NoL -C OSDPad $StartOSDPad"
    }

    if ($Startnet) {
        Write-Warning "The Startnet string is added to Startnet.cmd"
        Write-Warning "This must be set every time you run Edit-OSDCloud.winpe or it will revert back to defaults"

        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value $Startnet -Force
    }
    if ($StartOSDCloud -or $StartOSDCloudGUI -or $StartWebScript -or $StartOSDPad -or $Startnet){
        #Do Nothing
    }
    else {
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Startnet.cmd: start PowerShell -NoL"

        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value '@ECHO OFF' -Force
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value 'ECHO Start PowerShell' -Force
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value 'start PowerShell -NoL' -Force
    }
    #=================================================
    #   Wallpaper
    #=================================================
    if ($Wallpaper) {
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Wallpaper: $Wallpaper"
        Copy-Item -Path $Wallpaper -Destination "$env:TEMP\winpe.jpg" -Force | Out-Null
        Copy-Item -Path $Wallpaper -Destination "$env:TEMP\winre.jpg" -Force | Out-Null
        robocopy "$env:TEMP" "$MountPath\Windows\System32" winpe.jpg /ndl /njh /njs /b /np /r:0 /w:0
        robocopy "$env:TEMP" "$MountPath\Windows\System32" winre.jpg /ndl /njh /njs /b /np /r:0 /w:0
    }
    #=================================================
    #   Update OSD Module
    #=================================================
    Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Saving OSD Module to $MountPath\Program Files\WindowsPowerShell\Modules"
    Save-Module -Name OSD -Path "$MountPath\Program Files\WindowsPowerShell\Modules" -Force
    if ($AddAzure.IsPresent) {
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Saving Azure Modules to $MountPath\Program Files\WindowsPowerShell\Modules"
        Save-Module -Name Az.Accounts -Path "$MountPath\Program Files\WindowsPowerShell\Modules" -Force
        Save-Module -Name Az.Storage -Path "$MountPath\Program Files\WindowsPowerShell\Modules" -Force
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Saving AzCopy to $MountPath\Windows"
        $AzCopy = Save-WebFile -SourceUrl (Invoke-WebRequest -UseBasicParsing 'https://aka.ms/downloadazcopy-v10-windows' -MaximumRedirection 0 -ErrorAction SilentlyContinue).headers.location
        if ($AzCopy) {
            Expand-Archive -Path $AzCopy.FullName -DestinationPath $env:windir\Temp\AzCopy -Force
            Get-ChildItem -Path $env:windir\Temp\AzCopy -Recurse -Include azcopy.exe | foreach {Copy-Item $_.FullName -Destination "$MountPath\Windows\azcopy.exe" -Force -ErrorAction SilentlyContinue}
        }
    }
    if ($AddAws.IsPresent) {
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Saving AWS Modules to $MountPath\Program Files\WindowsPowerShell\Modules"
        Save-Module -Name AWS.Tools.Common "$MountPath\Program Files\WindowsPowerShell\Modules" -Force
        Save-Module -Name AWS.Tools.S3 -Path "$MountPath\Program Files\WindowsPowerShell\Modules" -Force
    }
    #=================================================
    #   PSModuleInstall
    #=================================================
    foreach ($Module in $PSModuleInstall) {
        if ($Module -eq 'DellBiosProvider') {
            if (Test-Path "$env:SystemRoot\System32\msvcp140.dll") {
                Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Copying $env:SystemRoot\System32\msvcp140.dll to WinPE"
                Copy-Item -Path "$env:SystemRoot\System32\msvcp140.dll" -Destination "$MountPath\System32" -Force | Out-Null
            }
            if (Test-Path "$env:SystemRoot\System32\vcruntime140.dll") {
                Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Copying $env:SystemRoot\System32\vcruntime140.dll to WinPE"
                Copy-Item -Path "$env:SystemRoot\System32\vcruntime140.dll" -Destination "$MountPath\System32" -Force | Out-Null
            }
            if (Test-Path "$env:SystemRoot\System32\msvcp140.dll") {
                Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Copying $env:SystemRoot\System32\vcruntime140_1.dll to WinPE"
                Copy-Item -Path "$env:SystemRoot\System32\vcruntime140_1.dll" -Destination "$MountPath\System32" -Force | Out-Null
            }
        }
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Saving $Module to $MountPath\Program Files\WindowsPowerShell\Modules"
        Save-Module -Name $Module -Path "$MountPath\Program Files\WindowsPowerShell\Modules" -Force
    }
    #=================================================
    #   PSModuleCopy
    #=================================================
    foreach ($Module in $PSModuleCopy) {
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Copy-PSModuleToWindowsImage -Name $Module -Path $MountPath"
        Copy-PSModuleToWindowsImage -Name $Module -Path $MountPath
    }
    #=================================================
    #   Save WIM
    #=================================================
    $MountMyWindowsImage | Dismount-MyWindowsImage -Save
    #=================================================
    #	UpdateUsb
    #=================================================
    if ($UpdateUsb) {
        $WinpeVolume = (Get-Volume.usb | Where-Object {$_.FileSystemLabel -eq 'WinPE'}).DriveLetter
    
        if ($WinpeVolume) {
            Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) Copying $WorkspacePath\Media to $($WinpeVolume):\"
            robocopy "$WorkspacePath\Media" "$($WinpeVolume):\" *.* /e /ndl /np /njh /njs /b /r:0 /w:0 /zb /xd "$RECYCLE.BIN" "System Volume Information"
        }
    }
    #=================================================
    #	Complete
    #=================================================
    $WinpeEndTime = Get-Date
    $WinpeTimeSpan = New-TimeSpan -Start $WinpeStartTime -End $WinpeEndTime
    Write-Host -ForegroundColor DarkGray    "================================================"
    Write-Host -ForegroundColor Yellow      "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) $($MyInvocation.MyCommand.Name) " -NoNewline
    Write-Host -ForegroundColor Cyan        "Completed in $($WinpeTimeSpan.ToString("mm' minutes 'ss' seconds'"))"
    #=================================================
}