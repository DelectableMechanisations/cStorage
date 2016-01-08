#Sample configuration that does the following:
#   - Finds all CD Drives and configures them to use the last available drive letters (e.g. CD Drive D: becomes Z: and CD Drives D: & E: become Z: and Y:).
#   - Finds all disks that are currently offline and creates an NTFS volume on each of them using a 4096 block size and assigns them the first unused drive letter.
#   - Finds all volumes and renames them to %COMPUTERNAME%-%DRIVELETTER%-%EXISTING VOLUME LABEL% (e.g. volume D: with a label of 'Data' on Server01 is renamed to 'SERVER01-D-Data').


#Describe the configuration.
Configuration Sample_cStorage_ConfigureStorage {
    Param (
        [System.String[]]
        $NodeName,

        [ValidateSet('UseLastAvailable','Default')]
        [System.String]
        $CdRomDriveLetterAllocation = 'UseLastAvailable',

        [ValidateSet('AllOnline','Default')]
        [System.String]
        $DiskConfiguration,

        [ValidateSet('NTFS', 'ReFS', 'exFAT', 'FAT32', 'FAT')]
        [System.String]
        $FileSystem,

        [ValidateScript({@(4096, 8192, 16384, 32768, 65536) -contains $_})]
        [System.UInt32]
        $BlockSize,

        [ValidateSet('ComputerNameDriveLetterVolumeLabel','Default')]
        [System.String]
        $VolumeNamingScheme
    )
    Import-DscResource -ModuleName cStorage


    Node $NodeName {
        #Change the drive letters of all CD Drives so they use the last letters of the alphabet (i.e. instead of D: or E: use Z:, Y: etc).
        cCdDriveLetter CDDriveLetter {
            CdRomDriveLetterAllocation = $CdRomDriveLetterAllocation
        }


        #Find all disks that are offline, bring them online, create a formatted partition and assign each one a drive letter.
        cProvisionDisk FormatDisks {
            DiskConfiguration = $DiskConfiguration
            FileSystem = $FileSystem
            BlockSize = $BlockSize
            DependsOn = '[cCdDriveLetter]CDDriveLetter'
        }


        #Apply the standard naming convention to all volumes '%COMPUTERNAME%-%DRIVELETTER%-%VOLUME LABEL%' (e.g. volume D: with a label of 'Data' on Server01 is renamed to 'SERVER01-D-Data')
        cVolumeNamingScheme ApplyVolumeNamingScheme {
            VolumeNamingScheme = $VolumeNamingScheme
            DependsOn = '[cProvisionDisk]FormatDisks'
        }
    }
}


#Create the MOF File using the configuration described above.
Sample_cStorage_ConfigureStorage `
-CdRomDriveLetterAllocation  'UseLastAvailable' `
-DiskConfiguration 'AllOnline' `
-FileSystem 'NTFS' `
-BlockSize 4096 `
-VolumeNamingScheme 'ComputerNameDriveLetterVolumeLabel'


#Push the configuration to the computer.
Start-DscConfiguration -Path Sample_cStorage_ConfigureStorage -Wait -Verbose -Force