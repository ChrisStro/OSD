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
        [ValidateSet('Dell','HP','Intel','Nutanix','USB','VMware','WiFi')]
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
        [string]$Wallpaper,
        [string]$WorkspacePath
    )
    #=================================================
    #	Start the Clock
    #=================================================
    $WinpeStartTime = Get-Date
    #=================================================
    #	Cloud Drivers
    #=================================================
    $WinPECloudDriverDell           = 'http://downloads.dell.com/FOLDER07703466M/1/WinPE10.0-Drivers-A25-F0XPX.CAB'
    $WinPECloudDriverHp             = 'https://ftp.hp.com/pub/softpaq/sp112501-113000/sp112810.exe'
    $WinPECloudDriverIntelEthernet  = 'https://downloadmirror.intel.com/710138/Wired_driver_26.8_x64.zip'
    $WinPECloudDriverIntelWiFi      = 'https://downloadmirror.intel.com/655277/WiFi-22.80.1-Driver64-Win10-Win11.zip'
    $WinPECloudDriverNutanix        = 'https://github.com/OSDeploy/OSDCloud/raw/main/Drivers/WinPE/Nutanix.cab'
    $WinPECloudDriverUsb            = @(
                                            'USB\VID_045E&PID_0927' #Surface USB-C Ethernet
                                            'VID_0B95&PID_7720' #Asix AX88772 USB2.0 to Fast Ethernet Adapter
                                            'VID_0B95&PID_7E2B' #Asix AX8872B USB2.0
                                            'USB\VID_0BDA&PID_8153' #Realtek USB GbE Family Controller
                                            'USB\VID_17EF&PID_720C' #Lenovo USB-C Ethernet
                                        )
    $WinPECloudDriverVmware         = 'https://github.com/OSDeploy/OSDCloud/raw/main/Drivers/WinPE/VMware.cab'
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
        Write-Host "Setting Workspace Path"
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
    #   DriverPath
    #=================================================
    foreach ($Driver in $DriverPath) {
        Add-WindowsDriver -Path "$($MountMyWindowsImage.Path)" -Driver "$Driver" -Recurse -ForceUnsigned
    }
    #=================================================
    #   DriverHWID
    #=================================================
    if ($DriverHWID) {
        $HardwareIDDriverPath = Join-Path $env:TEMP (Get-Random)
        foreach ($Item in $DriverHWID) {
            Save-MsUpCatDriver -HardwareID $Item -DestinationDirectory $HardwareIDDriverPath
        }
        try {
            $null = Add-WindowsDriver -Path "$($MountMyWindowsImage.Path)" -Driver $HardwareIDDriverPath -Recurse -ForceUnsigned
        }
        catch {
            Write-Warning "Unable to find a driver for $Item"
        }
    }
    #=================================================
    #   WinPECloudDriverUsb
    #=================================================
    if ($WinPECloudDriverUsb) {
        $HardwareIDDriverPath = Join-Path $env:TEMP (Get-Random)
        Save-MsUpCatDriver -HardwareID $WinPECloudDriverUsb -DestinationDirectory $HardwareIDDriverPath
        Add-WindowsDriver -Path "$($MountMyWindowsImage.Path)" -Driver $HardwareIDDriverPath -Recurse -ForceUnsigned
    }
    #=================================================
    #   CloudDriver
    #=================================================
    foreach ($Driver in $CloudDriver) {
        if ($Driver -eq 'Dell'){
            Write-Verbose "Adding $Driver CloudDriver"
            if (Test-WebConnection -Uri $WinPECloudDriverDell) {
                $SaveWebFile = Save-WebFile -SourceUrl $WinPECloudDriverDell
                if (Test-Path $SaveWebFile.FullName) {
                    $DriverCab = Get-Item -Path $SaveWebFile.FullName
                    $ExpandPath = Join-Path $DriverCab.Directory $DriverCab.BaseName
            
                    if (-NOT (Test-Path $ExpandPath)) {
                        New-Item -Path $ExpandPath -ItemType Directory -Force | Out-Null
                    }
                    Expand -R "$($DriverCab.FullName)" -F:* "$ExpandPath" | Out-Null
                    Add-WindowsDriver -Path "$($MountMyWindowsImage.Path)" -Driver "$ExpandPath\winpe\x64" -Recurse -ForceUnsigned -Verbose
                }
            }
            else {
                Write-Warning "Unable to connect to $WinPECloudDriverDell"
            }
        }
        if ($Driver -eq 'Intel'){
            Write-Verbose "Adding $Driver Ethernet CloudDriver"
            if (Test-WebConnection -Uri $WinPECloudDriverIntelEthernet) {
                $SaveWebFile = Save-WebFile -SourceUrl $WinPECloudDriverIntelEthernet
                if (Test-Path $SaveWebFile.FullName) {
                    $DriverCab = Get-Item -Path $SaveWebFile.FullName
                    $ExpandPath = Join-Path $DriverCab.Directory $DriverCab.BaseName
                    Write-Verbose -Verbose "Expanding Intel Ethernet Drivers to $ExpandPath"
                    Expand-Archive -Path $DriverCab -DestinationPath $ExpandPath -Force
                    $IntelExe = Get-ChildItem -Path $ExpandPath 'Wired_driver_26.8_x64.exe'
                    $IntelExe | Rename-Item -newname { $_.name -replace '.exe','.zip' } -Force -ErrorAction Ignore
                    $IntelZip = Get-ChildItem -Path $ExpandPath 'Wired_driver_26.8_x64.zip' -Recurse
                    
                    $ExpandPath = Join-Path $IntelZip.Directory $IntelZip.BaseName
                    Expand-Archive -Path $IntelZip.FullName -DestinationPath $ExpandPath -Force
            
                    $NDIS65 = Get-ChildItem -Path $ExpandPath -Directory -Recurse | Where-Object {$_.Name -match 'NDIS65'}
            
                    foreach ($Item in $NDIS65) {
                        Add-WindowsDriver -Path "$($MountMyWindowsImage.Path)" -Driver $Item.FullName -Recurse -ForceUnsigned -Verbose
                    }
                }
            }
            else {
                Write-Warning "Unable to connect to $WinPECloudDriverIntelWiFi"
            }
        }
        if ($Driver -eq 'HP'){
            Write-Verbose "Adding $Driver CloudDriver"
            if (Test-WebConnection -Uri $WinPECloudDriverHp) {
                $SaveWebFile = Save-WebFile -SourceUrl $WinPECloudDriverHp
                if (Test-Path $SaveWebFile.FullName) {
                    $DriverCab = Get-Item -Path $SaveWebFile.FullName
                    $ExpandPath = Join-Path $DriverCab.Directory $DriverCab.BaseName

                    Write-Verbose -Verbose "Expanding HP Client Windows PE Driver Pack to $ExpandPath"
                    Start-Process -FilePath $DriverCab -ArgumentList "/s /e /f `"$ExpandPath`"" -Wait
                    Add-WindowsDriver -Path "$($MountMyWindowsImage.Path)" -Driver "$ExpandPath" -Recurse -ForceUnsigned -Verbose
                }
            }
            else {
                Write-Warning "Unable to connect to $WinPECloudDriverHp"
            }
        }
        if ($Driver -eq 'Nutanix'){
            Write-Verbose "Adding $Driver CloudDriver"
            if (Test-WebConnection -Uri $WinPECloudDriverNutanix) {
                $SaveWebFile = Save-WebFile -SourceUrl $WinPECloudDriverNutanix
                if (Test-Path $SaveWebFile.FullName) {
                    $DriverCab = Get-Item -Path $SaveWebFile.FullName
                    $ExpandPath = Join-Path $DriverCab.Directory $DriverCab.BaseName
            
                    if (-NOT (Test-Path $ExpandPath)) {
                        New-Item -Path $ExpandPath -ItemType Directory -Force | Out-Null
                    }
                    Expand -R "$($DriverCab.FullName)" -F:* "$ExpandPath" | Out-Null
                    Add-WindowsDriver -Path "$($MountMyWindowsImage.Path)" -Driver "$ExpandPath" -Recurse -ForceUnsigned -Verbose
                }
            }
            else {
                Write-Warning "Unable to connect to $WinPECloudDriverNutanix"
            }
        }
        if ($Driver -eq 'VMware'){
            Write-Verbose "Adding $Driver CloudDriver"
            if (Test-WebConnection -Uri $WinPECloudDriverVmware) {
                $SaveWebFile = Save-WebFile -SourceUrl $WinPECloudDriverVmware
                if (Test-Path $SaveWebFile.FullName) {
                    $DriverCab = Get-Item -Path $SaveWebFile.FullName
                    $ExpandPath = Join-Path $DriverCab.Directory $DriverCab.BaseName
            
                    if (-NOT (Test-Path $ExpandPath)) {
                        New-Item -Path $ExpandPath -ItemType Directory -Force | Out-Null
                    }
                    Expand -R "$($DriverCab.FullName)" -F:* "$ExpandPath" | Out-Null
                    Add-WindowsDriver -Path "$($MountMyWindowsImage.Path)" -Driver "$ExpandPath" -Recurse -ForceUnsigned -Verbose
                }
            }
            else {
                Write-Warning "Unable to connect to $WinPECloudDriverVmware"
            }
        }
        if ($Driver -eq 'WiFi'){
            Write-Verbose "Adding $Driver CloudDriver"
            if (Test-WebConnection -Uri $WinPECloudDriverIntelWiFi) {
                #$WiFiDownloads = (Invoke-WebRequest -Uri $WinPECloudDriverIntelWiFi -UseBasicParsing).Links
                #$WiFiDownloads = $WiFiDownloads | Where-Object {$_.download -match 'Driver64_Win10.zip'} | Sort-Object Download -Unique | Select-Object Download, Title -First 1
                #$SaveWebFile = Save-WebFile -SourceUrl $WiFiDownloads.download
                $SaveWebFile = Save-WebFile -SourceUrl $WinPECloudDriverIntelWiFi
                if (Test-Path $SaveWebFile.FullName) {
                    $DriverCab = Get-Item -Path $SaveWebFile.FullName
                    $ExpandPath = Join-Path $DriverCab.Directory $DriverCab.BaseName
                    Write-Verbose -Verbose "Expanding Intel Wireless Drivers to $ExpandPath"

                    Expand-Archive -Path $DriverCab -DestinationPath $ExpandPath -Force
                    Add-WindowsDriver -Path "$($MountMyWindowsImage.Path)" -Driver "$ExpandPath" -Recurse -ForceUnsigned -Verbose
                }
            }
            else {
                Write-Warning "Unable to connect to $WinPECloudDriverIntelWiFi"
            }
        }
        Save-WindowsImage -Path $MountPath
    }
    #=================================================
    #   Drop initial Startnet.cmd
    #=================================================
    $OSDVersion = (Get-Module -Name OSD -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
    Write-Host -ForegroundColor DarkGray "Startnet.cmd: wpeinit"
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
        Write-Host -ForegroundColor DarkGray 'Startnet.cmd: start PowerShell -NoL -C Start-WinREWiFi'
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

        Write-Host -ForegroundColor DarkGray "Startnet.cmd: start /wait PowerShell -NoL -C `"$StartPSCommand`""
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value "start /wait PowerShell -NoL -C `"$StartPSCommand`"" -Force
    }
    #=================================================
    #   StartWebScript /wait
    #=================================================
    if ($StartWebScript) {
        Write-Warning "The StartWebScript parameter is adding your Cloud PowerShell script to Startnet.cmd"
        Write-Warning "This must be set every time you run Edit-OSDCloud.winpe or it will revert back to defaults"

        Write-Host -ForegroundColor DarkGray "Startnet.cmd: start /wait PowerShell -NoL -C Invoke-WebPSScript '$StartWebScript'"
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
        
        Write-Host -ForegroundColor DarkGray "Startnet.cmd: start /wait PowerShell -NoL -C Start-OSDCloud $StartOSDCloud"
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
        
        Write-Host -ForegroundColor DarkGray 'Startnet.cmd: start /wait PowerShell -NoL -W Mi -C Start-OSDCloudGUI'
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
        
        Write-Host -ForegroundColor DarkGray "Startnet.cmd: start /wait PowerShell -NoL -C OSDPad $StartOSDPad"
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
        Write-Host -ForegroundColor DarkGray "Startnet.cmd: start PowerShell -NoL"

        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value '@ECHO OFF' -Force
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value 'ECHO Start PowerShell' -Force
        Add-Content -Path "$MountPath\Windows\System32\Startnet.cmd" -Value 'start PowerShell -NoL' -Force
    }
    #=================================================
    #   Wallpaper
    #=================================================
    if ($Wallpaper) {
        Write-Host -ForegroundColor DarkGray "Wallpaper: $Wallpaper"
        Copy-Item -Path $Wallpaper -Destination "$env:TEMP\winpe.jpg" -Force | Out-Null
        Copy-Item -Path $Wallpaper -Destination "$env:TEMP\winre.jpg" -Force | Out-Null
        robocopy "$env:TEMP" "$MountPath\Windows\System32" winpe.jpg /ndl /njh /njs /b /np /r:0 /w:0
        robocopy "$env:TEMP" "$MountPath\Windows\System32" winre.jpg /ndl /njh /njs /b /np /r:0 /w:0
    }
    #=================================================
    #   Update OSD Module
    #=================================================
    Write-Host -ForegroundColor DarkGray "Saving OSD Module to $MountPath\Program Files\WindowsPowerShell\Modules"
    Save-Module -Name OSD -Path "$MountPath\Program Files\WindowsPowerShell\Modules" -Force
    if ($AddAzure.IsPresent) {
        Write-Host -ForegroundColor DarkGray "Saving Azure Modules to $MountPath\Program Files\WindowsPowerShell\Modules"
        Save-Module -Name Az.Accounts -Path "$MountPath\Program Files\WindowsPowerShell\Modules" -Force
        Save-Module -Name Az.Storage -Path "$MountPath\Program Files\WindowsPowerShell\Modules" -Force
        Write-Host -ForegroundColor DarkGray "Saving AzCopy to $MountPath\Windows"
        $AzCopy = Save-WebFile -SourceUrl (Invoke-WebRequest -UseBasicParsing 'https://aka.ms/downloadazcopy-v10-windows' -MaximumRedirection 0 -ErrorAction SilentlyContinue).headers.location
        if ($AzCopy) {
            Expand-Archive -Path $AzCopy.FullName -DestinationPath $env:windir\Temp\AzCopy -Force
            Get-ChildItem -Path $env:windir\Temp\AzCopy -Recurse -Include azcopy.exe | foreach {Copy-Item $_.FullName -Destination "$MountPath\Windows\azcopy.exe" -Force -ErrorAction SilentlyContinue}
        }
    }
    if ($AddAws.IsPresent) {
        Write-Host -ForegroundColor DarkGray "Saving AWS Modules to $MountPath\Program Files\WindowsPowerShell\Modules"
        Save-Module -Name AWS.Tools.Common "$MountPath\Program Files\WindowsPowerShell\Modules" -Force
        Save-Module -Name AWS.Tools.S3 -Path "$MountPath\Program Files\WindowsPowerShell\Modules" -Force
    }
    #=================================================
    #   PSModuleInstall
    #=================================================
    foreach ($Module in $PSModuleInstall) {
        if ($Module -eq 'DellBiosProvider') {
            if (Test-Path "$env:SystemRoot\System32\msvcp140.dll") {
                Write-Host -ForegroundColor DarkGray "Copying $env:SystemRoot\System32\msvcp140.dll to WinPE"
                Copy-Item -Path "$env:SystemRoot\System32\msvcp140.dll" -Destination "$MountPath\System32" -Force | Out-Null
            }
            if (Test-Path "$env:SystemRoot\System32\vcruntime140.dll") {
                Write-Host -ForegroundColor DarkGray "Copying $env:SystemRoot\System32\vcruntime140.dll to WinPE"
                Copy-Item -Path "$env:SystemRoot\System32\vcruntime140.dll" -Destination "$MountPath\System32" -Force | Out-Null
            }
            if (Test-Path "$env:SystemRoot\System32\msvcp140.dll") {
                Write-Host -ForegroundColor DarkGray "Copying $env:SystemRoot\System32\vcruntime140_1.dll to WinPE"
                Copy-Item -Path "$env:SystemRoot\System32\vcruntime140_1.dll" -Destination "$MountPath\System32" -Force | Out-Null
            }
        }
        Write-Host -ForegroundColor DarkGray "Saving $Module to $MountPath\Program Files\WindowsPowerShell\Modules"
        Save-Module -Name $Module -Path "$MountPath\Program Files\WindowsPowerShell\Modules" -Force
    }
    #=================================================
    #   PSModuleCopy
    #=================================================
    foreach ($Module in $PSModuleCopy) {
        Write-Host -ForegroundColor DarkGray "Copy-PSModuleToWindowsImage -Name $Module -Path $MountPath"
        Copy-PSModuleToWindowsImage -Name $Module -Path $MountPath
    }
    #=================================================
    #   Save WIM
    #=================================================
    $MountMyWindowsImage | Dismount-MyWindowsImage -Save
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