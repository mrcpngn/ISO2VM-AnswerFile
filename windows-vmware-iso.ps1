Param(
    [string]$vmwaretools,
    [string]$answerfile
)

$rootDir = (Get-Location).Path
$Timestamp=(Get-Date -Format "MM-dd-yyyy-HHmm")

# Dependencies Apps
$ADKisInstalled = (Get-Package | Where-Object {$_.name -match 'Windows Assessment and Deployment Kit'}).Name -match "Windows Assessment and Deployment Kit"


# Functions
Function CreateDirectory {

    Param([string] $name)

    $folderCheck = Test-Path -Path $rootDir\$name

    If ($folderCheck -eq $false) {

        New-Item -ItemType Directory -Path $rootDir\$name | Out-Null
        Write-Host "[INFO] $name has been created."

    }
    
}

Function DownloadVMWareTools {
    
    Param([string]$url)

    $VMwareToolsIsoFullName = $url.split("/")[-1]

    $VMwareToolsIsoPath = "$rootDir\CustomISO\Temp\VMwareTools\" + $VMwareToolsIsoFullName

    # Check TSL1.2 if enable
    $checkTls12 = [System.Net.ServicePointManager]::SecurityProtocol.HasFlag([Net.SecurityProtocolType]::Tls12)

    # Set TSL1.2 to enable if false
    if ($checkTls12 -eq $false) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }

    $vmwaretoolsExist = Test-Path -Path "$rootDir\CustomISO\Temp\VMwareTools\$VMwareToolsIsoFullName" 
    
    # Download the VMWareTools
    If ( $vmwaretoolsExist -eq $false ) {
        Write-Host "[INFO] Downloading $VMwareToolsIsoFullName."
        (New-Object System.Net.WebClient).DownloadFile($url, $VMwareToolsIsoPath)
        Write-Host "[INFO] Finished downloading $VMwareToolsIsoFullName."
    }
    else {
        Write-Host "[INFO] $VMwareToolsIsoFullName already exist."
    }

    
}

Function MountWindowsISO {

    Param([string]$iso_path)
    $global:WindowsIsoPrompt = $iso_path.Split('\')[-1]
    $MountSourceWindowsIso = Mount-DiskImage -imagepath $iso_path -passthru
    # Get the drive letter assigned to the iso.
    $global:DriveSourceWindowsIso = ($MountSourceWindowsIso | get-volume).driveletter + ':'

    Write-Host "[INFO] $WindowsIsoPrompt has been mounted."

}

Function MountVMToolsISO {

    $global:VMwareToolsIsoFullPath = (Get-ChildItem "$rootDir\CustomISO\Temp\VMwareTools\" -Recurse -Filter *.iso).FullName
    $global:VMwareToolsIsoFullPrompt = $VMwareToolsIsoFullPath.Split('\')[-1]

    $MountVMwareToolsIso = Mount-DiskImage -imagepath $VMwareToolsIsoFullPath -passthru
    # Get the drive letter assigned to the iso.
    $global:DriveVMwareToolsIso = ($MountVMwareToolsIso  | get-volume).driveletter + ':'

    Write-Host "[INFO] $VMwareToolsIsoFullPrompt has been mounted."

}

Function CopyFromSource {

    Param([string]$windows, [string]$vmtools)

    # Copy the content of the Source Windows Iso to a Working Folder
    Write-Host "[INFO] Copying the Windows image files."
    Copy-Item $windows\* -Destination "$rootDir\CustomISO\Temp\WorkingFolder" -force -recurse
    Write-Host "[INFO] Finished copying the Windows image files."
    

    # Remove the read-only attribtue from the extracted files.
    Get-Childitem "$rootDir\CustomISO\Temp\WorkingFolder" -recurse | %{ if (! $_.psiscontainer) { $_.isreadonly = $false } }

    #  Copy VMware tools exe in a custom folder in the future ISO
    #For 64 bits by default.
    Write-Host "[INFO] Copying the VMwareTools installer."
    Copy-Item "$vmtools\setup64.exe" -Destination 'CustomISO\Temp\WorkingFolder\CustomFolder'
    Write-Host "[INFO] Finished copying VMwareTools installer."
}

Function MountPVSCSIDrivers {

    Write-Host "[INFO] Installing PVSCSI Drivers."
    Get-WindowsImage -ImagePath "$rootDir\CustomISO\Temp\WorkingFolder\sources\boot.wim" | foreach-object {
        Mount-WindowsImage -ImagePath "$rootDir\CustomISO\Temp\WorkingFolder\sources\boot.wim" -Index ($_.ImageIndex) -Path "$rootDir\CustomISO\Temp\MountDISM"
        Add-WindowsDriver -path "$rootDir\CustomISO\Temp\MountDISM" -driver $pvcsciPath -ForceUnsigned 
        Dismount-WindowsImage -path "$rootDir\CustomISO\Temp\MountDISM" -save
    } | Out-Null
    Write-Host "[INFO] Successfully installed PVSCSI drivers."

}

Function ModifyWindowsImage {

    Write-Host "[INFO] Updating Windows Image."

    $global:MountedWindowsImageWin = (Get-WindowsImage -ImagePath "$rootDir\CustomISO\Temp\WorkingFolder\sources\install.wim" | Where-Object { $_.ImageName -match "SERVERDATACENTER" -and $_.ImageName -notmatch "SERVERDATACENTERCORE" -or $_.ImageName -match "Desktop Experience" -and $_.ImageName -notmatch "Standard Evaluation" }).ImageIndex
    
    if ($MountedWindowsImageWin -ne $null) {

        Mount-WindowsImage -ImagePath "$rootDir\CustomISO\Temp\WorkingFolder\sources\install.wim" -Index $MountedWindowsImageWin -Path "$rootDir\CustomISO\Temp\MountDISM" | Out-Null
        Add-WindowsDriver -path "$rootDir\CustomISO\Temp\MountDISM" -driver $pvcsciPath -ForceUnsigned | Out-Null
        Dismount-WindowsImage -path "$rootDir\CustomISO\Temp\MountDISM" -save | Out-Null

        Write-Host "[INFO] Successfully updated Windows Image."

    } 
    else {

        Write-Host "[ERROR] install.wim Index is null"
    }

}

Function SetAnswerFile {

    $xmlPath = (Get-ChildItem -Path "$rootDir\$answerfile").FullName
    Copy-Item $xmlPath -Destination "$rootDir\CustomISO\Temp\WorkingFolder\Autounattend.xml"
    Write-Host "[INFO] Successfully copied answer file."
}

Function ConvertISO {

    # 12. Convert the ISO
    Write-Host "[INFO] Started converting custom ISO."
    $OcsdimgPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg"
    $oscdimg  = "$OcsdimgPath\oscdimg.exe"
    $etfsboot = "$OcsdimgPath\etfsboot.com"
    $efisys   = "$OcsdimgPath\efisys.bin"
    $ISO_WORKINGFOLDER = "$rootDir\CustomISO\Temp\WorkingFolder"

    $data = '2#p0,e,b"{0}"#pEF,e,b"{1}"' -f $etfsboot, $efisys
    start-process $oscdimg -args @("-bootdata:$data",'-u2','-udfver102', $ISO_WORKINGFOLDER, $DestinationWindowsIsoPath) -wait -nonewwindow
    Write-Host "[INFO] Finished creating a custom ISO."
}

# Iso variables
$isoSource = Get-ChildItem -path $rootDir -File '*.iso'
$isoBase = ($isoSource.Basename)


# Main scripts
If ($ADKisInstalled -eq $true) {

    # 1. Create the folders for the custom iso creation
    CreateDirectory -name CustomISO
    CreateDirectory -name CustomISO\Temp
    CreateDirectory -name CustomISO\Temp\WorkingFolder
    CreateDirectory -name CustomISO\Temp\WorkingFolder\CustomFolder
    CreateDirectory -name CustomISO\Temp\VMwareTools
    CreateDirectory -name CustomISO\Temp\MountDISM
    CreateDirectory -name FinalISO
    
    # 2. Prepare path for the Windows ISO destination file
    $DestinationWindowsIsoPath = "$rootDir\FinalISO\$isoBase" + "-custom-" + $Timestamp + ".iso"

    # 3. Get the ISO Full Path
    $ISOFullPath = ($isoSource.FullName)
    
    # 4. Download VMware Tools ISO
    DownloadVMWareTools -url $vmwaretools

    # 5. Mount the source Windows iso.
    MountWindowsISO -iso_path $ISOFullPath

    # 6. Mount VMware tools ISO
    MountVMToolsISO

    # 7. Copy the content of the Source Windows Iso and VMwareTools ISO to a Working Folder
    CopyFromSource -windows $DriveSourceWindowsIso -vmtools $DriveVMwareToolsIso

    # 8. Inject PVSCSI Drivers in boot.wim and install.vim
    $pvcsciPath = $DriveVMwareToolsIso + '\Program Files\VMware\VMware Tools\Drivers\pvscsi\Win8\amd64\pvscsi.inf'

    # 9. Mount the the boot.wim and add the PVSCSI Drivers
    MountPVSCSIDrivers

    # 10. Get the Serverdatacenter image on install.wim.
    # Mount the datacernter image and add PVSCI Drivers then save
    ModifyWindowsImage
    
    # 11. Copy the answer file
    SetAnswerFile

    # 12. Convert ISO file
    ConvertISO

    # 13. Dismount the ISOs files
    Dismount-DiskImage -ImagePath $ISOFullPath
    Dismount-DiskImage -ImagePath $VMwareToolsIsoFullPath
    
    Write-Host "[INFO] Successfully unmounted $WindowsIsoPrompt." 
    Write-Host "[INFO] Successfully unmounted $VMwareToolsIsoFullPrompt."

    Remove-Item -Path $rootDir\CustomISO\ -Recurse -Force
    Write-Host "[INFO] Finished cleaning up custom ISO folder."
    

}
else {

    Write-Host "[WARN] Please install Microsoft Windows ADK inorder to proceed."

}