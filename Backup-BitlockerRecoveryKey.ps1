[CmdletBinding()]
param(
  [Parameter(Mandatory)] [String]$driveLetter
)

#if they only put the driver letter, add the :
if ($driveLetter -like "?") {
    $driveLetter = $driveLetter+":"
}

$blVolume = Get-BitLockerVolume -MountPoint $driveLetter
$keyProtector = $blVolume.KeyProtector | Where-object{$_.KeyProtectorType -eq "RecoveryPassword"}

$keyProtector.KeyProtectorId

Backup-BitLockerKeyProtector -MountPoint $driveLetter -KeyProtectorId $keyProtector.KeyProtectorId