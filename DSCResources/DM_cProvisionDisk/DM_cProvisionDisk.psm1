<#===============================================================================================================================================================================

DM_cProvisionDisk.psm1

AUTHOR:         David Baumbach
Version:        1.0.0
Creation Date:  17/10/2015
Last Modified:  01/01/2016


This DSC module is a more automated way of provisioning disks on a server than the xDisk/xStorage DSC module created by Microsoft.
It will search the system for any offline disks and if it finds any it will bring them online, format them and assign them drive letters.


Change Log:
    0.0.1   17/10/2015  Initial Creation
    1.0.0   01/01/2016  First Published


The code used to build the module.
    Import-Module xDSCResourceDesigner
    $DiskConfiguration = New-xDscResourceProperty -Name DiskConfiguration -Type String -Attribute Key -ValidateSet @('AllOnline','Default')
    $FileSystem = New-xDscResourceProperty -Name FileSystem -Type String -Attribute Write -ValidateSet @('NTFS', 'ReFS', 'exFAT', 'FAT32', 'FAT')
    $BlockSize = New-xDscResourceProperty -Name BlockSize -Type UInt32 -Attribute Write
    $DisksOffline = New-xDscResourceProperty -Name DisksOffline -Type UInt32 -Attribute Read
    $DisksOnline = New-xDscResourceProperty -Name DisksOnline -Type UInt32 -Attribute Read

    New-xDscResource -Name DM_cProvisionDisk -FriendlyName cProvisionDisk -Property $DiskConfiguration, $FileSystem, $BlockSize, $DisksOffline, $DisksOnline `
    -Path ([System.Environment]::GetFolderPath('Desktop')) -ModuleName cStorage

===============================================================================================================================================================================#>


#The Get-TargetResource function wrapper.
Function Get-TargetResource {
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('AllOnline','Default')]
        [System.String]$DiskConfiguration,

        [ValidateSet('NTFS', 'ReFS', 'exFAT', 'FAT32', 'FAT')]
        [System.String]$FileSystem,

        [ValidateScript({@(4096, 8192, 16384, 32768, 65536) -contains $_})]
        [System.UInt32]$BlockSize
	)

    ValidateProperties @PSBoundParameters -Mode Get
}




#The Set-TargetResource function wrapper.
Function Set-TargetResource {
	[CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('AllOnline','Default')]
        [System.String]$DiskConfiguration,
        
        [ValidateSet('NTFS', 'ReFS', 'exFAT', 'FAT32', 'FAT')]
        [System.String]$FileSystem,

        [ValidateScript({@(4096, 8192, 16384, 32768, 65536) -contains $_})]
        [System.UInt32]$BlockSize
	)

    ValidateProperties @PSBoundParameters -Mode Set
}




#The Test-TargetResource function wrapper.
Function Test-TargetResource {
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	Param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('AllOnline','Default')]
        [System.String]$DiskConfiguration,
        
        [ValidateSet('NTFS', 'ReFS', 'exFAT', 'FAT32', 'FAT')]
        [System.String]$FileSystem,

        [ValidateScript({@(4096, 8192, 16384, 32768, 65536) -contains $_})]
        [System.UInt32]$BlockSize
	)

    ValidateProperties @PSBoundParameters -Mode Test
}




#This function has all the smarts in it and is used to do all of the configuring.
Function ValidateProperties {

    [CmdletBinding()]
	Param (
        [ValidateSet('AllOnline','Default')]
        [System.String]$DiskConfiguration,
        
        [ValidateSet('NTFS', 'ReFS', 'exFAT', 'FAT32', 'FAT')]
        [System.String]$FileSystem,

        [ValidateScript({@(4096, 8192, 16384, 32768, 65536) -contains $_})]
        [System.UInt32]$BlockSize,

        [Parameter(Mandatory = $true)]
		[ValidateSet('Get','Set','Test')]
		[System.String]$Mode = 'Get'
	)
    

    #Get a list of all disks on the computer and divide them into separate variables for offline and online disks.
    [Array]$List_Disks = Get-Disk | Sort-Object -Property Location
    [Array]$List_OfflineDisks = $List_Disks | Where-Object {$_.IsOffline -eq $true}
    [Array]$List_OnlineDisks = $List_Disks | Where-Object {$_.IsOffline -eq $false}


    #If there is more than 1 disk offline then changes may need to be made.
    switch ($List_OfflineDisks.Count -ge 1) {
        $true  {$CurrentDiskConfiguration = 'Default'}
        $false {$CurrentDiskConfiguration = 'AllOnline'}
    }
        



    #If $DiskConfiguration is 'Default' no changes will need to be made.
    #-------------------------------------------------------------------
    if ($DiskConfiguration -eq 'Default') {
        switch ($Mode) {
            'Get'  {
                $ReturnData = @{
                    DisksOffline = $List_OfflineDisks.Count
                    DisksOnline = $List_OnlineDisks.Count
                    CurrentDiskConfiguration = 'Default'
                }
                Return $ReturnData
            }

            'Set'  {Write-Verbose -Message "As the '-DiskConfiguration' parameter is set to 'Default' no changes need to be made."}
            'Test' {Write-Verbose -Message "As the '-DiskConfiguration' parameter is set to 'Default' no changes need to be made."; Return $true}
        }




    #If $DiskConfiguration is 'AllOnline' changes may need to be mad.
    #----------------------------------------------------------------
    } elseif ($DiskConfiguration -eq 'AllOnline') {
        switch ($Mode) {
            'Get'  {
                $ReturnData = @{
                    DisksOffline = $List_OfflineDisks.Count
                    DisksOnline = $List_OnlineDisks.Count
                    CurrentDiskConfiguration = $CurrentDiskConfiguration
                }
                Return $ReturnData
            }

            'Set'  {
                if ($CurrentDiskConfiguration -eq 'AllOnline') {
                    Write-Verbose -Message "There are 0 offline disks on this system so no changes need to be made."

                } else {
                    
                    Write-Verbose -Message "Stopping the 'ShellHWDetection' to prevent Windows from prompting to format the volume."
                    Stop-Service -Name ShellHWDetection

                    #Provision each disk that is currently offline.
                    foreach ($Disk in $List_OfflineDisks) {
                        try {
                            Write-Verbose "Bringing Disk $($Disk.Number) online."
                            $Disk | Set-Disk -IsOffline $false
        
                            if ($Disk.IsReadOnly -eq $true) {
                                Write-Verbose "Removing the 'ReadOnly' flag from Disk $($Disk.Number)."
                                $Disk | Set-Disk -IsReadOnly $false
                            }

                            Write-Verbose -Message "Checking existing disk partition style on Disk $($Disk.Number)."
                            if (($Disk.PartitionStyle -ne "GPT") -and ($Disk.PartitionStyle -ne "RAW")) {
                                Throw "Disk '$($Disk.Number)' is already initialised with '$($Disk.PartitionStyle)'"

                            } else {
                                if ($Disk.PartitionStyle -eq "RAW") {
                                    Write-Verbose -Message "Initializing Disk '$($Disk.Number)'."
                                    $Disk | Initialize-Disk -PartitionStyle "GPT" -PassThru

                                } else {
                                    Write-Verbose -Message "Disk '$($Disk.Number)' is already configured for 'GPT'."
                                }
                            }


                            #Assign the offline disk the first unused drive letter.
                            $DriveLetter = Get-DriveLetter -FirstUnused
                            Write-Verbose -Message "Creating a partition on Disk $($Disk.Number) and assigning it the Drive Letter '$($DriveLetter)'."
                            $PartParams = @{
                                DriveLetter = $DriveLetter
                                DiskNumber = $Disk.Number
                                UseMaximumSize = $true
                            }

                            $Partition = New-Partition @PartParams
        
                            # Sometimes the disk will still be read-only after the call to New-Partition returns.
                            Start-Sleep -Seconds 5

                            $VolParams = @{
                                Confirm = $false
                            }

                            #Default to using NTFS if no File System has been specified.
                            if ($FileSystem) {
                                $VolParams["FileSystem"] = $FileSystem
        
                            } else {
                                $VolParams["FileSystem"] = 'NTFS'
                            }

                            #Default to 4096 if no Block Size has been specified.
                            if ($BlockSize) {
                                $VolParams["AllocationUnitSize"] = $BlockSize

                            } else {
                                $VolParams["AllocationUnitSize"] = 4096
                            }

                            Write-Verbose -Message "Formatting volume '$($DriveLetter)' with the $($VolParams.FileSystem) file system and a block size of $($VolParams.AllocationUnitSize)."
                            $Volume = $Partition | Format-Volume @VolParams


                            if ($Volume) {
                                Write-Verbose -Message "Successfully initialized '$($PartParams.DriveLetter)' with the $($VolParams.FileSystem) file system  and a block size of $($VolParams.AllocationUnitSize)."
                            }
                        } catch {
                            Throw "Disk Set-TargetResource failed with the following error: '$($Error[0])'"
                        }
                    } #End foreach

                    Write-Verbose -Message "Restarting the 'ShellHWDetection' service."
                    Start-Service -Name ShellHWDetection
                }
            }
            'Test' {
                if ($CurrentDiskConfiguration -eq 'Default') {
                    Write-Verbose -Message "There are $($List_OfflineDisks.Count) offline disks on this system."
                    Return $false

                } elseif ($CurrentDiskConfiguration -eq 'AllOnline') {
                    Write-Verbose -Message "There are 0 offline disks on this system."
                    Return $true
                }
            }
        }
    }
}




Function Get-DriveLetter {
        
    Param(
        [Switch]$FirstUnused,
        [Switch]$LastUnused,
        [Switch]$AllUnused
    )

    #Creates an array of all the drive letters that are currently being used in Windows.
    [Array]$UsedLetters = [System.IO.DriveInfo]::GetDrives() | Select-Object -ExpandProperty Name | ForEach-Object {$_.Substring(0,1)}


    #Creates an array of all the letters of the alphabet from D to Z (I could have included A,B,C in here but I thought it might cause issues).
    [Array]$AllLetters = 68..90 | ForEach-Object {[Char]$_}
        
        
        
        
    #When the '$AllUnused' switch parameter is used the function will return all drive letters that have not been assigned to devices.
    if ($AllUnused) {
        $UnusedLetters = @()
        for ($a=0;$a -lt 23;$a++) {
            if ($UsedLetters -notcontains $AllLetters[$a]) {
                $UnusedLetters += $AllLetters[$a]
            }
        }
        Return $UnusedLetters
        
    #When the 'FirstUnused' switch parameter is used the function will return the first drive letter that has not already been assigned to a device.
    } elseif ($FirstUnused) {
        [Int32]$c = 0
        [Bool]$FoundFreeLetter = $false
        Do {
            if ($UsedLetters -contains $AllLetters[$c]) {
                $c++
            } else {
                $FoundFreeLetter = $true
            }

        } While ($FoundFreeLetter -eq $false)
            
        Return $AllLetters[$c]
            
    #When the 'LastUnused' switch parameter is used the function will return the last drive letter that has not already been assigned to a device.        
    } elseif ($LastUnused) {
        [Int32]$c = $AllLetters.Count -1
        [Bool]$FoundFreeLetter = $false
        Do {
            if ($UsedLetters -contains $AllLetters[$c]) {
                $c--
            } else {
                $FoundFreeLetter = $true
            }

        } While ($FoundFreeLetter -eq $false)
            
        Return $AllLetters[$c]
            
    #Running the function without parameters will return all the drive letters that have been assigned to devices.
    } else {
        Return $UsedLetters
    }
}

Export-ModuleMember -Function *-TargetResource