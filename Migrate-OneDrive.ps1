$dept = "DERPARTMENT NAME"
$server = "FILE SERVER FQDN"
$autogroup = "AD SECURITY GROUP"

New-Item -ItemType Directory -Name Migration -Path "\\$server\D$\DATA\Groups"

#Generate user table for CED/Tech to verify employment status
Get-ADGroupMember -Identity $autogroup | Where-Object{$_.objectclass -eq "User"} | Get-ADUser | Where-Object Enabled -eq "True" | Sort-Object SamAccountName | Select-Object SamAccountName,GivenName,Surname | Out-GridView

#Remove empty user folders    
$empties = Get-ChildItem \\$server\D$\DATA\Users -Directory -Recurse -Depth 0 | Where-Object -FilterScript {($_.GetFiles().Count -eq 0) -and $_.GetDirectories().Count -eq 0} | Select-Object -ExpandProperty Name | sort

foreach ($empty in $empties) {

    Remove-Item \\$server\D$\DATA\Users\$empty
}

#Check provisioning status of OneDrive for users within a specific Autogroup
Import-Module SharePointPNPPowerShellOnline
$creds = Get-Credential
function Check-OneDrive {
    Param (
        #AutoGroup Name
        [Parameter(Mandatory=$true,Position=1)]
        [String]$AutoGroup

        )


    $users = Get-ADGroupMember -Identity $autogroup | Where-Object{$_.objectclass -eq "User"} | Get-ADUser | Where-Object Enabled -eq "True" | Sort-Object SamAccountName
        
    foreach ($user in $users) {
        if (Test-Path "\\$server\D$\DATA\Users\$($User.SamAccountName)") {
            #Clean up user name containing "."
            if ($user.SamAccountName.ToString() | Select-String -SimpleMatch ".") {
                $fixed = ($user.SamAccountName.ToString()).Replace(".","_")
            }
            else {
                $fixed = $user.SamAccountName.ToString()
            }
            
            #Check document library URL 
            $url = try {Invoke-WebRequest -Uri "https://uflorida-my.sharepoint.com/personal/$($fixed)_ufl_edu/_layouts/15/onedrive.aspx" -UseBasicParsing}
            
            catch {$_.Exception.Response}
        
            if ($url.StatusCode -ne "200") {
                $OneDrive = $false
                $Access = "Denied"
            }
        
            else {
                
                $OneDrive = $true
                $Access = "True"

                try {
                    $RootUrl = "https://uflorida-my.sharepoint.com/personal/$($fixed)_ufl_edu"
                    Connect-PnPOnline –Url $RootUrl –Credentials $Creds
                    Get-PnPSiteCollectionAdmin -ErrorAction Stop | Out-Null
                    Disconnect-PnPOnline
                }

                catch{
                    $access = "Denied"
                }
            }
        
                    $properties = @{
        
                    UserName = $user.SamAccountName
                    First = $user.GivenName
                    Last = $user.Surname
                    EMail = $user.UserPrincipalName
                    OneDrive = $OneDrive
                    StatusCode = $url.StatusCode
                    Access = $access
                    URL = "https://uflorida-my.sharepoint.com/personal/$($fixed)_ufl_edu"
                    #County = ($user.DistinguishedName.Split(",")[1]).Replace("OU=","")
                        }
                    
                    New-Object -TypeName psobject -Property $properties
        
        }
    }
}
    
Check-OneDrive $autogroup | Sort-Object UserName | Export-Csv "C:\Users\dehyatt\OneDrive - University of Florida\Desktop\OneDriveMigration$dept.csv" -NoTypeInformation

####################################################################################################################################################################################
#Get remaining folders
####################################################################################################################################################################################

$folders = Get-ChildItem \\$server\D$\DATA\Users -Directory | Select-Object -ExpandProperty Name | sort

#Users with OneDrive
$users = Import-Csv -Path "C:\Users\dehyatt\OneDrive - University of Florida\Desktop\OneDriveMigration$dept.csv" | Where-Object {$_.OneDrive -eq "True" -and $_.Access -eq "True"}

#E-Mail list of orphaned user folders to CED? Maybe?
$orphans = Compare-Object -ReferenceObject $users.UserName -DifferenceObject $folders -PassThru | Where-Object {$_.SideIndicator -eq "=>"} | Get-ADUser 

#Move Orphaned Folders to \\$server\D$\DATA\Groups\Migration\Orphans

New-Item -Path \\$server\D$\DATA\Groups\Migration -Name Orphans -ItemType Directory

foreach ($orphan in $orphans.SamAccountName) {

    Move-Item -Path "\\$server\D$\DATA\Users\$orphan" -Destination "\\$server\D$\DATA\Groups\Migration\Orphans"
}


#Build CSV for Migration Tool

$users = (Get-ChildItem -Path "\\$server\D$\DATA\Users" -Attributes Directory).Name

foreach ($user in $users) {
    #Clean up user name containing "."
    if ($user | Select-String -SimpleMatch ".") {$fixed = $user.Replace(".","_")}
     else {$fixed = $user}

     #$directory = Get-ChildItem "\\$server\D$\DATA\Users" | Where-Object {$_.Name -match $user} | Select-Object -ExpandProperty FullName
     $directory = Join-Path -Path "\\localhost\$server_DATA\Groups\Migration\Users" -ChildPath $user

     $properties = @{
    
        Directory = $directory
        LocalLib = $null
        LocalSubfolder = $null        
        Site = "https://uflorida-my.sharepoint.com/personal/$($fixed)_ufl_edu"
        Library = 'Documents'
        Subfolder = 'MigratedData'
    }
    New-Object -TypeName psobject -Property $properties | Select-Object Directory,LocalLib,LocalSubfolder,Site,library,Subfolder | Export-Csv -Append -NoTypeInformation -Path \\$server\D$\DATA\Groups\Migration\Migrate$Dept.csv  

}

$Directory = "\\localhost\$server_DATA\Groups\Migration\Unit"

$properties = @{
    
    Directory = $Directory
    LocalLib = $null
    LocalSubfolder = $null        
    Site = "https://uflorida.sharepoint.com/teams/IFAS-$Dept-Ext/"
    Library = 'Documents'
    Subfolder = 'General/Unit'
    }
New-Object -TypeName psobject -Property $properties | Select-Object Directory,LocalLib,LocalSubfolder,Site,library,Subfolder | Export-Csv -Append -NoTypeInformation -Path \\$server\D$\DATA\Groups\Migration\Migrate$Dept.csv

$csv = Get-Content \\$server\D$\DATA\Groups\Migration\Migrate$Dept.csv | Select-Object -Skip 1
Set-Content -Value $csv \\$server\D$\DATA\Groups\Migration\Migrate$Dept.csv



#Move Content to be migrated prior to DPM backup running at 6pm.

#Kill all open files?

Invoke-Command -ScriptBlock {Get-SmbOpenFile | Select-Object ClientUserName,Locks,Path} -ComputerName "$server"

Invoke-Command -ScriptBlock {Get-SmbOpenFile | Close-SmbOpenFile} -ComputerName "$server"
Move-Item -Path "\\$server\D$\DATA\Users" -Destination "\\$server\D$\DATA\Groups\Migration"
Move-Item -Path "\\$server\D$\DATA\Groups\Unit" -Destination "\\$server\D$\DATA\Groups\Migration"