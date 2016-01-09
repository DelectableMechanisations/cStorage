<#===============================================================================================================================================================================

DM_cCdDriveLetter.psm1

AUTHOR:         David Baumbach
Version:        1.0.2
Creation Date:  31/07/2015
Last Modified:  09/01/2016


This DSC module is used to find any CD Drives on a computer and modify their Drive Letters so they use the last available (unused) drive letter.
e.g     A computer with 1 x CD Drive will have it re-mapped to Z:
        A computer with 2 x CD Drives will have them re-mapped to Y: and Z:


Change Log:
    0.0.1   31/07/2015  Initial Creation
    1.0.0   01/01/2016  First Published
    1.0.1   08/01/2016  Corrected an invalid property in the hash table returned by Get-TargetResource (CurrentCdRomDriveLetterAllocation instead of CdRomDriveLetterAllocation).
    1.0.2   09/01/2016  Fixed the bug introduced by the change above.


The code used to build the module.
    Import-Module xDSCResourceDesigner
    $CdRomDriveLetterAllocation = New-xDscResourceProperty -Name CdRomDriveLetterAllocation -Type String -Attribute Key -ValidateSet 'UseLastAvailable', 'Default'
    $CdRomAllocatedDriveLetters = New-xDscResourceProperty -Name CdRomAllocatedDriveLetters -Type String -Attribute Read

    New-xDscResource -Name DM_cCdDriveLetter -FriendlyName cCdDriveLetter -Property $CdRomDriveLetterAllocation, $CdRomAllocatedDriveLetters -Path ([System.Environment]::GetFolderPath('Desktop')) -ModuleName cStorage

===============================================================================================================================================================================#>



#The Get-TargetResource function wrapper.
Function Get-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('UseLastAvailable','Default')]
        [System.String]
        $CdRomDriveLetterAllocation = 'Default'
    )

    ValidateProperties @PSBoundParameters -Mode Get
}




#The Set-TargetResource function wrapper.
Function Set-TargetResource {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('UseLastAvailable','Default')]
        [System.String]
        $CdRomDriveLetterAllocation = 'Default'
    )

    ValidateProperties @PSBoundParameters -Mode Set
}




#The Test-TargetResource function wrapper.
Function Test-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('UseLastAvailable','Default')]
        [System.String]
        $CdRomDriveLetterAllocation = 'Default'
    )

    ValidateProperties @PSBoundParameters -Mode Test
}




#This function has all the smarts in it and is used to do all of the configuring.
Function ValidateProperties {
    [CmdletBinding()]
    Param (
        [ValidateSet('UseLastAvailable','Default')]
        [System.String]
        $CdRomDriveLetterAllocation = 'Default',

        [Parameter(Mandatory = $true)]
        [ValidateSet('Get','Set','Test')]
        [System.String]
        $Mode = 'Get'
    )
    
    $CdRomAllocatedDriveLetters = ''
    $CurrentCdRomDriveLetterAllocation = 'UseLastAvailable'

    #Get a list of all CD ROM drives on the computer.
    [Array]$List_CdDrives = Get-CimInstance -Query "SELECT * FROM Win32_Volume WHERE DriveType=5"


    #Continue on if there is more than 1 CD ROM drive.
    if ($List_CdDrives.Count -ge 1) {
        foreach ($CdDrive in $List_CdDrives) {
            $CurrentDriveLetter = $CdDrive.DriveLetter.Substring(0,1)
            $CdRomAllocatedDriveLetters += "$CurrentDriveLetter,"

            if ($CdRomDriveLetterAllocation -eq 'UseLastAvailable') {
                #Find the last available drive letter.
                $LastFreeDriveLetter = Get-DriveLetter -LastUnused




                #If the current drive letter is less than the last available drive letter...
                #---------------------------------------------------------------------------
                if ([Int32](([String]$CurrentDriveLetter).ToUpper())[0] -lt [Int32]($LastFreeDriveLetter)[0]) {
                    <##>Write-Verbose -Message "The CD ROM Drive '$CurrentDriveLetter`:' is not using the Last Available Drive Letter."

                    switch ($Mode) {
                        'Set'  {
                            <##>Write-Verbose -Message "Changing CD ROM Drive Letter from '$CurrentDriveLetter`:' to '$LastFreeDriveLetter`:'."
                            Set-CimInstance -InputObject $CdDrive -Property @{DriveLetter = ($LastFreeDriveLetter + ':')}
                        }

                        'Test' {$CurrentCdRomDriveLetterAllocation = 'Default'}
                    }




                #If the current drive letter is greater than the last available drive letter then do nothing.
                #--------------------------------------------------------------------------------------------
                } else {
                    <##>Write-Verbose -Message "The CD ROM Drive '$CurrentDriveLetter`:' is using the Last Available Drive Letter and does not need to be changed."
                }

            }
        } #End foreach




        #If $CdRomDriveLetterAllocation is 'Default' no changes will need to be made.
        #----------------------------------------------------------------------------
        if ($CdRomDriveLetterAllocation -eq 'Default') {
            switch ($Mode) {
                'Get'  {
                    $ReturnData = @{
                        CdRomAllocatedDriveLetters = $CdRomAllocatedDriveLetters.TrimEnd()
                        CdRomDriveLetterAllocation = 'Default'
                    }
                    Return $ReturnData
                }

                'Set'  {<##>Write-Verbose -Message "As the '-CdRomDriveLetterAllocation' parameter is set to 'Default' no changes need to be made."}
                'Test' {<##>Write-Verbose -Message "As the '-CdRomDriveLetterAllocation' parameter is set to 'Default' no changes need to be made."; Return $true}
            }




        #If $CdRomDriveLetterAllocation is 'UseLastAvailable' changes can be made if necessary.
        #--------------------------------------------------------------------------------------
        } elseif ($CdRomDriveLetterAllocation -eq 'UseLastAvailable') {
            switch ($Mode) {
                'Get'  {
                    $ReturnData = @{
                        CdRomAllocatedDriveLetters = $CdRomAllocatedDriveLetters.TrimEnd()
                        CdRomDriveLetterAllocation = $CurrentCdRomDriveLetterAllocation
                    }
                    Return $ReturnData
                }

                'Set'  {<##>Write-Verbose -Message "Command processing is complete and changes have been made where applicable."}
                'Test' {
                    if ($CurrentCdRomDriveLetterAllocation -eq 'Default') {
                        Return $false

                    } elseif ($CurrentCdRomDriveLetterAllocation -eq 'UseLastAvailable') {
                        Return $true
                    }
                }
            }
        }

    } else {
        <##>Write-Verbose -Message "The computer $($env:COMPUTERNAME) does not have any CD ROM drives connected to it. No changes will be made."

        switch ($Mode) {
            'Get'  {
                $ReturnData = @{
                    CdRomAllocatedDriveLetters = ''
                    CdRomDriveLetterAllocation = 'None'
                }
                Return $ReturnData
            }
            'Test' {Return $true}
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