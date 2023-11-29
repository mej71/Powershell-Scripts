#Input a CSV list of usernames, outputs a csv containing more in depth info about each user: department, manager, manager's email, user's primary address
#Input CSV should have the header "Username"
Add-Type -AssemblyName System.Windows.Forms
Import-Module ActiveDirectory

#Initival variables
$curDir = Get-Location
$outPath = $PSScriptRoot + '\UserInfo-' + (Get-Date -Format "dddd_MM-dd-yyyy_HH-mm") + '.csv'

$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ InitialDirectory = $curDir }
$FileBrowser.filter = "Csv (*.csv)| *.csv"

$FileBrowser.Title = "Choose Username CSV"
$FileBrowser.ShowDialog()
$userReport = Import-Csv $FileBrowser.FileName

$outputCSVArray = New-Object System.Collections.ArrayList

#only run if files were selected
if ($null -ne $userReport ){
    ForEach($Value in $userReport) {
        $obj = New-Object System.Object
        $adUser = $null
        $username = $Value."Username"
        $department = ""
        $managerName = ""
        $description = ""
        try {
            #Write-Host $username
            $adUser = Get-ADUser -Identity $username -Property 'Manager','UserPrincipalName', 'Department'
            $userPrincipalName = $adUser.UserPrincipalName
            $department = $adUser.Department
            if ($null -eq $adUser.Manager) {       
                $managerName = "N/A"
                $managerEmail = "N/A"                         
            } else {
                $manager = Get-ADUser $adUser.Manager | Get-ADObject -Properties 'UserPrincipalName', 'DisplayName'
                $managerEmail = $manager.UserPrincipalName
                $managerName = $manager.DisplayName
            }
        } catch {
            $userPrincipalName = "N/A"
            $managerName = "N/A"
            $managerEmail = "N/A"
            $department = "N/A"
            $description = ("Error, AD account " + $username + " not found.")
        }
        $obj | Add-Member -type NoteProperty -name "AD Username" -value $username
        $obj | Add-Member -type NoteProperty -name "Department" -value $department
        $obj | Add-Member -type NoteProperty -name "User Email" -value $userPrincipalName
        $obj | Add-Member -type NoteProperty -name "Manager" -value $managerName
        $obj | Add-Member -type NoteProperty -name "Manager's Primary Email" -value $managerEmail
        $obj | Add-Member -type NoteProperty -name "Description" -value $description
        [void]$outputCSVArray.Add($obj)
    }
    
    $outputCSVArray | Export-Csv -Path $outPath -NoTypeInformation
} else {
    Write-Host "No csv selected, or format was invalid."
}