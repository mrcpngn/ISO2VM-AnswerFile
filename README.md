# Automate Windows Server Installation

This script will automatically create a Windows Server ISO file with VMwareTools preinstalled.

Things to Note:
1. Before you start you must install first Windows ADK:
https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install
2. Place the ISO file with the same path of the 'create-winiso-vmwaretools.ps1' script.
3. The script must be run in Administrative privileges.
4. You must supply your own ISO file.
5. You can use the included unattened-xml or you can use your own.
6. You can use the default vmwaretools version to install.

Steps:
1. Open powershell with administrator privileges 
2. Go to the directory custom-iso-windows
    cd C:\Users\admin\Desktop\customiso\custom-iso-windows\
3. Choose your preffered autounattend.xml and tagname
4. Execute the script.
5. Final ISO will be saved on C:\Users\admin\Desktop\customiso\windows directory

Syntax:
.\create-winiso-vmwaretools.ps1 -iso <iso_file> -xml <unattended_xml> -url <vmwaretools_url> -tag <new_iso_name>

Sample:
.\create-winiso-vmwaretools.ps1 -iso Windows-2019-EN.iso -xml win2019-autounattend-en.xml -url https://packages.vmware.com/tools/esx/7.0u3/windows/VMware-tools-windows-11.3.0-18090558.iso -tag golden-iso-v1.0
