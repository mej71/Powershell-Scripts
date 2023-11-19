[CmdletBinding()]
param(
  [Parameter(Mandatory)] [String]$username1,
  [Parameter(Mandatory)] [String]$username2,
  [String]$domainFQDN
)

Import-Module -Name ActiveDirectory

Function GetUserGroupMembership {
    param ([Parameter(Mandatory)][String]$user, [String]$domainName)
    try {
        if ($domainName) {
            return Get-ADPrincipalGroupMembership -Identity $user -ResourceContextServer  $domainName | Select-Object Name
        } else {
            return Get-ADPrincipalGroupMembership -Identity $user | Select-Object Name
        }
    } catch {
        Write-Host $_.Exception.Message
        Write-Host "Unable to obtain Group Memberships for "$user", please make sure this username was entered correctly, and you are searching on the correct domain.  Terminating script"
        exit 55
    }
    return 
}

Function CreateUserInfoObject {
    param ([Parameter(Mandatory)][String]$user)
    $infoObject = [PSCustomObject]@{
        Name = $user
        AllGroups = New-Object System.Collections.ArrayList
        UniqueGroups = New-Object System.Collections.ArrayList
    }
    $infoObject.AllGroups = @(GetUserGroupMembership $user $domainFQDN)
    return $infoObject
}

#cleanup parameters
$username1 = $username1.Trim()
$username2 = $username2.Trim()

$user1Info = CreateUserInfoObject($username1)

$user2Info = CreateUserInfoObject($username2)
$user2Info.UniqueGroups = $user2Info.AllGroups | ForEach-Object {$_} #make deep copy of array

$nonUniqueGroups = @()

#Run through all groups for user1 and compare to user2, use add/remove functions to correct UniqueGroups
foreach ($group1 in $user1Info.AllGroups) {
    $foundMatch = $false
    foreach ($group2 in $user2Info.AllGroups) {
        if ($group1 -eq $group2) {
            $nonUniqueGroups.Add($group1)
            $foundMatch = $true
            break
        }
    }
    if (!$foundMatch) {
        $user1Info.UniqueGroups.Add($group1) | out-null
    } else {
        $user2Info.UniqueGroups.Remove($group1) | out-null
    }
}





