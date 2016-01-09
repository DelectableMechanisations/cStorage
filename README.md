# cStorage
DSC Module containing resources used to configure Storage on a Windows Computer

This is my own take on Microsoft's xDisk/xStorage module and contains the following resources:

cCdDriveLetter - This DSC module is used to find any CD Drives on a computer and modify their Drive Letters so they use the last available (unused) drive letter.
e.g     A computer with 1 x CD Drive will have it re-mapped to Z:
        A computer with 2 x CD Drives will have them re-mapped to Y: and Z:
		
cProvisionDisk - This DSC module is a more automated way of provisioning disks on a server than the xDisk/xStorage DSC module created by Microsoft. It will search the system for any offline disks and if it finds any it will bring them online, format them and assign them drive letters.

cVolumeNamingScheme - This DSC module is used to apply a Standard naming scheme to all volumes on a computer. This naming scheme is %COMPUTERNAME%-%DRIVELETTER%-%EXISTING VOLUME LABEL% and will only apply to volumes that don't match this naming scheme.