# Parameter properties
Param(
    [string] $iso,
    [string] $xml,
    [string] $url,
    [string] $tag
)

# 1. Create the folders for the custom iso creation
New-Item -ItemType Directory -Path CustomISO
New-Item -ItemType Directory -Path CustomISO\FinalIso
New-Item -ItemType Directory -Path CustomISO\UnattendXML
New-Item -ItemType Directory -Path CustomISO\Temp
New-Item -ItemType Directory -Path CustomISO\Temp\WorkingFolder
New-Item -ItemType Directory -Path CustomISO\Temp\VMwareTools
New-Item -ItemType Directory -Path CustomISO\Temp\MountDISM

# 2. Prepare path for the Windows ISO destination file
$SourceWindowsIsoFullName = $iso.split("\")[-1]
$DestinationWindowsIsoPath = "$pwd\CustomISO\FinalIso\" +  ($SourceWindowsIsoFullName -replace ".iso","") + "$tag.iso"

# 3. Get the ISO Full Path
$ISOFullPath = Get-ChildItem -Path $iso -Filter $iso -Recurse | %{$_.FullName}

# 4. Download VMware Tools ISO  
$VMwareToolsIsoFullName = $url.split("/")[-1]
$VMwareToolsIsoPath = "$pwd\CustomISO\Temp\VMwareTools\" + $VMwareToolsIsoFullName 
(New-Object System.Net.WebClient).DownloadFile($url, $VMwareToolsIsoPath)
$VMwareToolsIsoFullPath = Get-ChildItem -Path $VMwareToolsIsoFullName -Filter $VMwareToolsIsoFullName -Recurse | %{$_.FullName}

# 5. Mount the source Windows iso.
$MountSourceWindowsIso = Mount-DiskImage -imagepath $ISOFullPath -passthru
# Get the drive letter assigned to the iso.
$DriveSourceWindowsIso = ($MountSourceWindowsIso | get-volume).driveletter + ':'

# 6. Mount VMware tools ISO
$MountVMwareToolsIso = Mount-DiskImage -imagepath $VMwareToolsIsoFullPath -passthru
# Get the drive letter assigned to the iso.
$DriveVMwareToolsIso = ($MountVMwareToolsIso  | get-volume).driveletter + ':'

# 7. Copy the content of the Source Windows Iso to a Working Folder
Copy-Item $DriveSourceWindowsIso\* -Destination "$pwd\CustomISO\Temp\WorkingFolder" -force -recurse

# Remove the read-only attribtue from the extracted files.
get-childitem "$pwd\CustomISO\Temp\WorkingFolder" -recurse | %{ if (! $_.psiscontainer) { $_.isreadonly = $false } }

# 8. Copy VMware tools exe in a custom folder in the future ISO
New-Item -ItemType Directory -Path "$pwd\CustomISO\Temp\WorkingFolder\CustomFolder"
#For 64 bits by default.
Copy-Item "$DriveVMwareToolsIso\setup64.exe" -Destination 'CustomISO\Temp\WorkingFolder\CustomFolder'

# 9. Inject PVSCSI Drivers in boot.wim and install.vim
$pvcsciPath = $DriveVMwareToolsIso + '\Program Files\VMware\VMware Tools\Drivers\pvscsi\Win8\amd64\pvscsi.inf'

# 10. Mount the the boot.wim and add the PVSCSI Drivers
# Optional check all Image Index for boot.wim
# Get-WindowsImage -ImagePath "$pwd\CustomISO\Temp\WorkingFolder\sources\boot.wim"

Get-WindowsImage -ImagePath "$pwd\CustomISO\Temp\WorkingFolder\sources\boot.wim" | foreach-object {
	Mount-WindowsImage -ImagePath "$pwd\CustomISO\Temp\WorkingFolder\sources\boot.wim" -Index ($_.ImageIndex) -Path "$pwd\CustomISO\Temp\MountDISM"
	Add-WindowsDriver -path "$pwd\CustomISO\Temp\MountDISM" -driver $pvcsciPath -ForceUnsigned
	Dismount-WindowsImage -path "$pwd\CustomISO\Temp\MountDISM" -save
}

# 10. Mount the the install.vim and add the PVSCSI Drivers
# Optional check all Image Index for install.wim
# Get-WindowsImage -ImagePath "$pwd\CustomISO\Temp\WorkingFolder\sources\install.wim"

# Modify all images in "install.wim"
# Example for windows 2016 iso:
# Windows Server 2016 SERVERSTANDARDCORE
# Windows Server 2016 SERVERSTANDARD
# Windows Server 2016 SERVERDATACENTERCORE
# Windows Server 2016 SERVERDATACENTER

$MountedWindowsImageWin = Get-WindowsImage -ImagePath "$pwd\CustomISO\Temp\WorkingFolder\sources\install.wim" | Where-Object ImageName -match "Datacenter Evaluation (Desktop Experience)*" 
Mount-WindowsImage -ImagePath "$pwd\CustomISO\Temp\WorkingFolder\sources\install.wim" -Index $MountedWindowsImageWin.ImageIndex -Path "$pwd\CustomISO\Temp\MountDISM"
Add-WindowsDriver -path "$pwd\CustomISO\Temp\MountDISM" -driver $pvcsciPath -ForceUnsigned
Dismount-WindowsImage -path "$pwd\CustomISO\Temp\MountDISM" -save

# 11. Add the autaunattend xml for a basic configuration AND the installation of VMware tools.
$XMLFullPath = Get-ChildItem -Path $xml -Filter $xml -Recurse | %{$_.FullName}
Copy-Item $XMLFullPath -Destination "$pwd\CustomISO\Temp\WorkingFolder\autounattend.xml"

# 12. Convert the ISO
$OcsdimgPath = 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg'
$oscdimg  = "$OcsdimgPath\oscdimg.exe"
$etfsboot = "$OcsdimgPath\etfsboot.com"
$efisys   = "$OcsdimgPath\efisys.bin"
$ISO_WORKINGFOLDER = "$pwd\CustomISO\Temp\WorkingFolder"

$data = '2#p0,e,b"{0}"#pEF,e,b"{1}"' -f $etfsboot, $efisys
start-process $oscdimg -args @("-bootdata:$data",'-u2','-udfver102', $ISO_WORKINGFOLDER, $DestinationWindowsIsoPath) -wait -nonewwindow

# 13. Save the final ISO
$FinaISOName = ($SourceWindowsIsoFullName -replace "$tag.iso","")
$FinalISOFullPath = Get-ChildItem -Path  $FinaISOName -Filter $FinaISOName -Recurse | %{$_.FullName}

# 14. Dismount the ISOs files
Dismount-DiskImage -ImagePath $ISOFullPath
Dismount-DiskImage -ImagePath $VMwareToolsIsoFullPath

# 15. Move the Final ISO to the desktop folder ad delete the customISO folder
Move-Item -Path $FinalISOFullPath -Destination "C:\Users\admin\Desktop\customiso\windows\$tag.iso"
Remove-Item -Path "$pwd\CustomISO\" -Force -Recurse
