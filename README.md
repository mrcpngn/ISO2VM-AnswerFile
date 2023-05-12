# Automate Windows Server Installation

This script will automatically create a Windows Server ISO file with VMwareTools preinstalled.

## Things to Note

1. Before you start you must install first [Windows ADK](https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install):
2. Place the ISO file with the same path of the 'windows-vmware-iso.ps1' script.
3. The script must be run in Administrative privileges.
4. You must supply your own ISO file.
5. You can use the included sample answer files or you can use your own.
6. You can use the default vmwaretools version to install.

### Steps

1. Open powershell with administrator privileges 
2. Go to the home directory of the script
3. Use the sample answerfile or you can use your own.
4. Execute the script.
5. The ISO will be saved on the "FinalISO" folder

### Syntax

```
.\create-winiso-vmwaretools.ps1 -answerfile <unattended_xml> -vmwaretools <vmwaretools_url>
```

### Sample 

```
.\windows-vmware-iso.ps1 -answerfile unattend.xml -vmwaretools https://packages.vmware.com/tools/esx/7.0u3/windows/VMware-tools-windows-11.3.0-18090558.iso
```
## VMware Tools Repository 

You can view the list of VMware tools here:
https://packages.vmware.com/tools/esx/7.0u3/windows
