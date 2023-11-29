#Create's a csv report detailing each member of a particular AD group.  Includes blank fields for ticket information
#Intended to perform audits of groups

[CmdletBinding()]
param(
  [Parameter(Mandatory)] [String]$ADGroup
)

$saveLocation = $PSScriptRoot + '\' + $ADGroup + (Get-Date -Format "dddd_MM-dd-yyyy_HH-mm") + '.csv'

Get-ADGroupMember -Identity $ADGroup | Get-ADUser | Select-Object GivenName, Surname, sAMAccountName, @{Name='Relevant Ticket'; Expression={''}}, @{Name='Was Removed?'; Expression={'False'}}, UserPrincipalName, @{Name='Notes'; Expression={''}} | Export-CSV $saveLocation -NoTypeInformation