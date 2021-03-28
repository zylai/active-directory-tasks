# Check if Msol cmdlet is installed
if (-Not (Get-Command -Module MSOnline -errorAction SilentlyContinue)) {
    echo "Msol is not installed. This script requires the Msol cmdlet to work"
    echo 'To install this module, run the following command in PowerShell as administrator (select "[A] Yes to All" when prompted):'
    echo ""
    echo "Install-Module MSOnline"
    echo ""
    echo "More info: https://docs.microsoft.com/en-us/microsoft-365/enterprise/connect-to-microsoft-365-powershell?view=o365-worldwide"
    echo ""
    Read-Host -Prompt "Press Enter to exit"
    exit
}

echo "Please enter your credentials when prompted"

# Prompt for authentication and connect to Azure AD
$authentication_status = $False
while (-not $authentication_status)
{
    $UserCredential = $host.ui.PromptForCredential("Credentials needed", "Use your UPN for the username.", "", "UPN")
    Connect-MsolService -Credential $UserCredential -errorAction SilentlyContinue

    $authentication_status = $?

    if ($authentication_status)
    {
        echo "Authentication successful"
    } 
    else
    {
        echo "Authentication failed, try again"
    }
}

# Instruction messages
echo "Processing... Please wait..."
echo ""

# Get current date to create unique filename to save output
$date = $(Get-Date -Format "yyyyMMdd")

# Get list of role GUIDs and save to $guids
$guids_raw = $(Get-MsolRole | Select ObjectId | ft -hidetableheaders | out-string)
$guids = $guids_raw.Trim()

# Counter for progress bar and count number of lines for progress bar
$progress_bar = 0
$num_lines = $(echo $guids | Measure-Object -Line | Select Lines -ExpandProperty Lines)

# Loop through each line in $guids and get UPN of users with the role
foreach($line in $($guids -split "`r`n"))
{
    Write-Progress -activity "Gathering data..." -status "Processed: $progress_bar of $num_lines roles" -percentComplete (($progress_bar / $num_lines)  * 100)

    # Only get email address if member type is a user and save in $result
    $result = $(Get-MsolRoleMember -RoleObjectId $line | Select RoleMemberType, EmailAddress -ExpandProperty EmailAddress)

    # Count number of lines in $result and if it's zero, that means the role does not have any users
    # In that case, save the name of the role in empty-roles.txt
    $num_users = $(echo $result | Measure-Object -Line | Select Lines -ExpandProperty Lines)
    if ($num_users -eq 0)
    {
        Get-MsolRole -ObjectId "$line" | Select Name -ExpandProperty Name >> ([Environment]::GetFolderPath("Desktop")+"\empty-roles-$date.txt")
        $progress_bar++
        continue
    }

    # Assuming the above if-statement is false, print name of the role and list of users
    Get-MsolRole -ObjectId "$line" | Select Name -ExpandProperty Name >> ([Environment]::GetFolderPath("Desktop")+"\audit-$date.txt")
    echo "---" >> ([Environment]::GetFolderPath("Desktop")+"\audit-$date.txt")
    echo $result >> ([Environment]::GetFolderPath("Desktop")+"\audit-$date.txt")
    echo "" >> ([Environment]::GetFolderPath("Desktop")+"\audit-$date.txt")

    $progress_bar++
}

# Print list of roles with no users by pasting empty-roles.txt back in
echo "====================" >> ([Environment]::GetFolderPath("Desktop")+"\audit-$date.txt")
echo "Roles with no users" >> ([Environment]::GetFolderPath("Desktop")+"\audit-$date.txt")
echo "====================" >> ([Environment]::GetFolderPath("Desktop")+"\audit-$date.txt")
Get-Content ([Environment]::GetFolderPath("Desktop")+"\empty-roles-$date.txt") >> ([Environment]::GetFolderPath("Desktop")+"\audit-$date.txt")

# Clean up empty-roles.txt file
Remove-Item ([Environment]::GetFolderPath("Desktop")+"\empty-roles-$date.txt")

echo "Results have been compiled and saved to `"audit-$date.txt`" on your desktop"
Read-Host -Prompt "Press Enter to exit"
exit
