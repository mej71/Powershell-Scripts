#Checks all users from each AD on your domain to see if they have not logged in within a specified threshold
#Default threshold is 30 days
[CmdletBinding()]
param(
  [String]$DomainName,
  [int]$DaysInactive
)

Import-Module -Name ActiveDirectory

# Check if the script is running as an administrator, as it will not function correctly in some instances
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires administrative privileges to work properly. Please run the script as an administrator."    
    exit # Exit the current script
}

$domainControllers = [System.Collections.ArrayList]@( Get-ADDomainController -Filter * | Select-Object Hostname )
$inactiveUsers = [PSCustomObject]@{}
$removedUsers = [System.Collections.ArrayList]@{} #if a user was removed, this means they have at least one logon date that is newer than the Inactive threshold
if (!$daysInactive) {
    $daysInactive = -30
} elseif ($daysInactive -ge 0) {
    $daysInactive = $daysInactive * -1
}

$counter = 0
foreach($dc in $domainControllers) {
    Write-Host $dc
    Write-Host $dc.GetType()
    $When = ((Get-Date).AddDays($daysInactive)).Date

    #if we are on the second DC or later, check the currently existing list of users to see if any have a newer greater logon date
    if ($counter -gt 0) {
        $existingUserSet = Get-ADUser -Server $dc -Filter {sAMAccountName -in $inactiveUsers."sAM Account Name"} -Properties * | select-object sAMAccountName,GivenName,Surname,LastLogonDate,Manager,Enabled
        foreach( $user in $existingUserSet) {
            if ($user.LastLogonDate -ge $When) {
                $removedUsers.Add($user.sAMAccountName)
                $inactiveUsers = $inactiveUsers | Where-Object {$_."sAM Account Name" -ne $user.sAMAccountName }
            }
        }
    }

    try {
        $users = [System.Collections.ArrayList]@(Get-ADUser -Server $dc -Filter {LastLogonDate -lt $When} -Properties * | select-object sAMAccountName,GivenName,Surname,LastLogonDate,Manager,Enabled)
        foreach( $user in $users) {
            $existingUser = $inactiveUsers | Select-Object -First | Where-Object {$_."sAM Account Name" -eq $value.sAMAccountName}
            #Don't add if user is already on list
            if ($existingUser) {
                #update LastLogonDate if there is a more recent one
                if ($existingUser."Last Logon Date" -ge $user.LastLogonDate) {
                    $existingUser."Last Logon Date" = $user.LastLogonDate
                }
                continue
            }
            #Skip users that were previously removed
            if ($removedUsers.Contains($value.sAMAccountName)) {
                continue
            }
            $obj = New-Object System.Object
            $obj | Add-Member -MemberType NoteProperty -Name "sAM Account Name" -Value $user.sAMAccountName
            $obj | Add-Member -MemberType NoteProperty -Name "Display Name" -Value ($user.GivenName + $user.Surname)
            $obj | Add-Member -MemberType NoteProperty -Name "Last Logon Date" -Value $user.LastLogonDate
            $obj | Add-Member -MemberType NoteProperty -Name "Manager" -Value $user.Manager
            try {
                $obj | Add-Member -MemberType NoteProperty -Name "Manager's Email" -Value ((Get-ADUser $user.Manager | Get-ADObject -Properties 'UserPrincipalName').UserPrincipalName)
            } catch{
                $obj | Add-Member -MemberType NoteProperty -Name "Manager's Email" -Value "N/A"
            }
            $obj | Add-Member -MemberType NoteProperty -Name "Is Enabled?" -Value $user.Enabled
            [void]$inactiveUsers.Add($obj)
        }
    } catch {
        Write-Host $_.Exception.Message
        exit 55
    }
    $counter = $counter + 1
}

#Now display inactive users
$inactiveUsers | Format-Table -AutoSize