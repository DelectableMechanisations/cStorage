<#===============================================================================================================================================================================

cDM_cVolumeNamingScheme.psm1

AUTHOR:         David Baumbach
Version:        1.0.1
Creation Date:  17/10/2015
Last Modified:  09/01/2016


This DSC resource is used to apply a Standard naming scheme to all volumes on a computer.
This naming scheme is %COMPUTERNAME%-%DRIVELETTER%-%EXISTING VOLUME LABEL% and will only apply to volumes that don't match this naming scheme.


Change Log:
    0.0.1   17/10/2015  Initial Creation
    1.0.0   01/01/2016  First Published
    1.0.1   09/01/2016  Cleaned up the parameters of all functions.


The code used to build the module.
    Import-Module xDSCResourceDesigner
    $VolumeNamingScheme = New-xDscResourceProperty -Name VolumeNamingScheme -Type String -Attribute Key -ValidateSet @('ComputerNameDriveLetterVolumeLabel','Default')
    $VolumesWithNamingScheme = New-xDscResourceProperty -Name VolumesWithNamingScheme -Type UInt32 -Attribute Read
    $VolumesWithoutNamingScheme = New-xDscResourceProperty -Name VolumesWithoutNamingScheme -Type UInt32 -Attribute Read

    New-xDscResource -Name DM_cVolumeNamingScheme -FriendlyName cVolumeNamingScheme -Property $VolumeNamingScheme, $VolumesWithNamingScheme, $VolumesWithoutNamingScheme `
    -Path ([System.Environment]::GetFolderPath('Desktop')) -ModuleName cStorage

===============================================================================================================================================================================#>


#The Get-TargetResource function wrapper.
Function Get-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('ComputerNameDriveLetterVolumeLabel','Default')]
        [System.String]
        $VolumeNamingScheme = 'Default'
    )

    ValidateProperties @PSBoundParameters -Mode Get
}




#The Set-TargetResource function wrapper.
Function Set-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('ComputerNameDriveLetterVolumeLabel','Default')]
        [System.String]
        $VolumeNamingScheme = 'Default'
    )

    ValidateProperties @PSBoundParameters -Mode Set
}




#The Test-TargetResource function wrapper.
Function Test-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('ComputerNameDriveLetterVolumeLabel','Default')]
        [System.String]
        $VolumeNamingScheme = 'Default'
    )

    ValidateProperties @PSBoundParameters -Mode Test
}




#This function has all the smarts in it and is used to do all of the configuring.
Function ValidateProperties {
    [CmdletBinding()]
    Param (
        [ValidateSet('ComputerNameDriveLetterVolumeLabel','Default')]
        [System.String]
        $VolumeNamingScheme = 'Default',

        [Parameter(Mandatory = $true)]
        [ValidateSet('Get','Set','Test')]
        [System.String]
        $Mode = 'Get'
    )
    

    #Get a list of all volumes on the system that don't have a naming scheme.
    [Array]$List_Volumes = Get-Partition | Where-Object {$_.IsSystem -eq $false} | Get-Volume
    [Array]$List_VolumesWithoutNamingScheme = $List_Volumes | Where-Object {$_.FileSystemLabel -notlike ($env:COMPUTERNAME + '-' + $_.DriveLetter + '-*')}
    [Array]$List_VolumesWithNamingScheme = $List_Volumes | Where-Object {$_.FileSystemLabel -like ($env:COMPUTERNAME + '-' + $_.DriveLetter + '-*')}


    #If there is more than 1 disk offline then changes may need to be made.
    switch ($List_VolumesWithoutNamingScheme.Count -ge 1) {
        $true  {$CurrentVolumeNamingScheme = 'Default'}
        $false {$CurrentVolumeNamingScheme = 'ComputerNameDriveLetterVolumeLabel'}
    }
        



    #If $VolumeNamingScheme is 'Default' no changes will need to be made.
    #--------------------------------------------------------------------
    if ($VolumeNamingScheme -eq 'Default') {
        switch ($Mode) {
            'Get'  {
                $ReturnData = @{
                    VolumesWithNamingScheme = $List_VolumesWithNamingScheme.Count
                    VolumesWithoutNamingScheme = $List_VolumesWithoutNamingScheme.Count
                    CurrentVolumeNamingScheme = 'Default'
                }
                Return $ReturnData
            }

            'Set'  {Write-Verbose -Message "As the '-VolumeNamingScheme' parameter is set to 'Default' no changes need to be made."}
            'Test' {Write-Verbose -Message "As the '-VolumeNamingScheme' parameter is set to 'Default' no changes need to be made."; Return $true}
        }




    #If $VolumeNamingScheme is 'ComputerNameDriveLetterVolumeLabel' changes may need to be made.
    #-------------------------------------------------------------------------------------------
    } elseif ($VolumeNamingScheme -eq 'ComputerNameDriveLetterVolumeLabel') {
        switch ($Mode) {
            'Get'  {
                $ReturnData = @{
                    VolumesWithNamingScheme = $List_VolumesWithNamingScheme.Count
                    VolumesWithoutNamingScheme = $List_VolumesWithoutNamingScheme.Count
                    CurrentVolumeNamingScheme = $CurrentVolumeNamingScheme
                }
                Return $ReturnData
            }

            'Set'  {
                if ($CurrentVolumeNamingScheme -eq 'ComputerNameDriveLetterVolumeLabel') {
                    Write-Verbose -Message "All volumes on this system are using the 'ComputerNameDriveLetterVolumeLabel' naming convention."

                } else {

                    #Rename each volume that isn't using the correct naming scheme.
                    foreach ($Volume in $List_VolumesWithoutNamingScheme) {
                        try {
                            $ExistingFileSystemLabel = $Volume.FileSystemLabel
                            Write-Verbose -Message "Existing volume label on $($Volume.DriveLetter) is '$ExistingFileSystemLabel'."

                            [String]$ExistingFileSystemLabel = $Volume.FileSystemLabel
                            [String]$NewFileSystemLabel = ($env:COMPUTERNAME.ToUpper() + '-' + $Volume.DriveLetter + '-' + $ExistingFileSystemLabel)
                            $Volume | Set-Volume -NewFileSystemLabel $NewFileSystemLabel

                            Write-Verbose -Message "Successfully renamed the volume label on $($Volume.DriveLetter) from '$ExistingFileSystemLabel' to '$NewFileSystemLabel'."

                        } catch {
                            Throw "Disk Set-TargetResource failed with the following error: '$($Error[0])'"
                        }
                    } #End foreach
                }
            }
            'Test' {
                if ($CurrentVolumeNamingScheme -eq 'Default') {
                    Write-Verbose -Message "$($List_VolumesWithoutNamingScheme.Count) volumes on this system are not using the 'ComputerNameDriveLetterVolumeLabel' naming convention."
                    Return $false

                } elseif ($CurrentVolumeNamingScheme -eq 'ComputerNameDriveLetterVolumeLabel') {
                    Write-Verbose -Message "All volumes on this system are using the 'ComputerNameDriveLetterVolumeLabel' naming convention."
                    Return $true
                }
            }
        }
    }
}

Export-ModuleMember -Function *-TargetResource