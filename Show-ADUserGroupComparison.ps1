[CmdletBinding()]
param(
  [Parameter(Mandatory)] [String]$Username1,
  [Parameter(Mandatory)] [String]$Username2,
  [String]$DomainName  
)

Import-Module -Name ActiveDirectory

# Check if the script is running as an administrator, as it will not function correctly in some instances
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires administrative privileges to work properly. Please run the script as an administrator."    
    exit # Exit the current script
}

Function GetUserGroupMembership {
    [OutputType([System.Collections.ArrayList])]
    param ([Parameter(Mandatory)][String]$user, [String]$domainName)
    try {
        if ($domainName) {
            $groupMembership= (Get-ADPrincipalGroupMembership -Identity $user -ResourceContextServer  $domainName | Select-Object -ExpandProperty Name)
        } else {
            $groupMembership = (Get-ADPrincipalGroupMembership -Identity $user | Select-Object -ExpandProperty Name)
        }

        # Ensure $groupMembership is always an array
        if ($null -eq $groupMembership) {
            $groupMembership = @()  # Empty array
        } elseif (-not $groupMembership -is [System.Collections.ICollection]) {
            $groupMembership = @($groupMembership)  # Convert to array
        }
        return [System.Collections.ArrayList]$groupMembership
    } catch {
        Write-Host $_.Exception.Message
        exit 55
    }
    return 
}

Function CreateUserInfoObject {
    param ([Parameter(Mandatory)][String]$user)
    $infoObject = [PSCustomObject]@{
        Name        = $user
        AllGroups   = [System.Collections.ArrayList]@(GetUserGroupMembership $user $domainName
        )
        UniqueGroups = [System.Collections.ArrayList]::New()
    }
    return $infoObject
}

#cleanup parameters
$username1 = $username1.Trim()
$username2 = $username2.Trim()

$user1Info = CreateUserInfoObject($username1)
$user2Info = CreateUserInfoObject($username2)
$user2Info.UniqueGroups = [System.Collections.ArrayList] $user2Info.AllGroups.Clone()

$nonUniqueGroups = New-Object System.Collections.ArrayList

#Run through all groups for user1 and compare to user2, use add/remove functions to correct UniqueGroups
foreach ($group1 in $user1Info.AllGroups) {
    $foundMatch = $false
    foreach ($group2 in $user2Info.AllGroups) {
        if ($group1.ToString() -eq $group2.ToString()) {
            $nonUniqueGroups.Add($group1) | out-null
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

#Write output as table
$output = [PSCustomObject]@{}
$output | Add-Member -MemberType NoteProperty -Name 'Shared Groups' -Value ([System.Collections.ArrayList] $nonUniqueGroups)
$output | Add-Member -MemberType NoteProperty -Name ($username1 + "'s Unique Groups") -Value ([System.Collections.ArrayList] $user1Info.UniqueGroups.Clone())
$output | Add-Member -MemberType NoteProperty -Name ($username2 + "'s Unique Groups")  -Value ([System.Collections.ArrayList] $user2Info.UniqueGroups.Clone())

$maxCount = ($output.PSObject.Properties | ForEach-Object { $_.Value.Count } | Measure-Object -Maximum).Maximum

$headersDisplayed = $false

# Calculate maximum column width for each column
$maxWidths = @{}
foreach ($property in $output.PSObject.Properties) {
    $maxWidths[$property.Name] = @($property.Value + $property.Name) | ForEach-Object { $_.Length } | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
}

for ($i = 0; $i -lt $maxCount; $i++) {
    $row = [PSCustomObject]@{}
    $row | Add-Member -MemberType NoteProperty -Name 'Shared Groups' -Value $null
    $row | Add-Member -MemberType NoteProperty -Name ($username1 + "'s Unique Groups") -Value $null
    $row | Add-Member -MemberType NoteProperty -Name ($username2 + "'s Unique Groups") -Value $null
    foreach ($property in $output.PSObject.Properties) {
        if ($i -lt $property.Value.Count) {
            $row."$($property.Name)" = $property.Value[$i]
        }
    }

    # Display headers only once
    if (-not $headersDisplayed) {
        $headersDisplayed = $true
        $row.PSObject.Properties | ForEach-Object { Write-Host -NoNewline $_.Name.PadRight($maxWidths[$_.Name] + 2); }
        Write-Host
    }

    $row.PSObject.Properties | ForEach-Object {
        $value = $_.Value
        $width = $maxWidths[$_.Name] + 2  # Adjusted width for spacing
        if ($value -eq $null) {
            $value = ""
        }
        Write-Host -NoNewline $value.PadRight($width)
    }
    Write-Host
}
