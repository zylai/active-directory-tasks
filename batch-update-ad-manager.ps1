##################################################
# This script searches for all the direct reports of a particular manager and replaces the direct reports' manager to a new manager.
# Useful for batch updating employees' manager when a manager leaves the organization.
#
# INSTRUCTIONS
# 1. Do not run this script as administrator, the script will prompt you for credentials when elevated privileges are needed
# 2. Enter username of out-going manager
# 3. The script will retrieve a list of that manager's direct reports; verify that this is correct
# 4. Enter username of new manager that will be replacing the outgoing manager
# 5. Enter credentials of an account with elevated privileges (needed to modify the manager field in AD)
# 6. If the new manager was promoted from within the department (used to report to the outgoing manager), the script will recognize this and prompt you for the new manager's manager
#
# CAVEATS
# 1. If the new manager is promoted from 2 levels underneath, this script will not recognize that. You'll have to manually change the manager of the new manager
##################################################

$CurrentManager = Read-Host "Enter current manager's username"

echo "Processing... Please wait..."
echo ""

$DirectReports = $(Get-ADUser -Filter * -Properties * | Select Name, SamAccountName, @{n='ManagerUsername';e={(Get-ADUser $_.Manager).SamAccountName}} | where-object {$_.ManagerUsername -contains "$CurrentManager"})
$DirectReportsCount = $(($DirectReports | Measure-Object | Select Count -ExpandProperty Count | Out-String).Trim())

if ($DirectReportsCount -eq 0)
{
    echo "No direct reports found"
    Read-Host -Prompt "Press Enter to exit"
    exit
}

echo "Found $DirectReportsCount direct reports:"
Write-Host ($DirectReports | Select Name, SamAccountName | Out-String)

$NewManager = Read-Host -Prompt "If this looks correct and you'd like to proceed with the update, enter the username of the new manager"
echo ""
$Credential = $host.ui.PromptForCredential("Need credentials", "Please enter your user name and password.", "", "NetBiosUserName")

$NewManagerObject = $(Get-ADUser -Filter {SamAccountName -eq $NewManager})
$NewManagerName = $(($NewManagerObject | Select Name -ExpandProperty Name | Out-String).Trim())

$SelfListedAsManager = $False

foreach ($Employee in $DirectReports)
{
    $EmployeeUsername = $(($Employee | Select SamAccountName -ExpandProperty SamAccountName | Out-String).Trim())
    $EmployeeName = $(($Employee | Select Name -ExpandProperty Name | Out-String).Trim())
    Get-ADUser -Filter {SamAccountName -eq $EmployeeUsername} | Set-ADUser -Credential $Credential -Manager $NewManagerObject

    if ($? -eq $True)
    {
        echo "Updated $EmployeeName`'s manager to $NewManagerName"
    }

    if ($EmployeeUsername -eq $NewManager)
    {
        $SelfListedAsManager = $True
        $SelfListedAsManagerObject = $Employee
    }
}

if ($SelfListedAsManager)
{
    $SelfListedAsManagerUsername = $(($SelfListedAsManagerObject | Select SamAccountName -ExpandProperty SamAccountName | Out-String).Trim())
    $SelfListedAsManagerName = $(($SelfListedAsManagerObject | Select Name -ExpandProperty Name | Out-String).Trim())

    echo ""
    echo "It seems like $SelfListedAsManagerName ($SelfListedAsManagerUsername) was promoted from within the department and is now listed as their own manager."
    $SelfListedEmployeeNewManagerUsername = Read-Host -Prompt "Enter $SelfListedAsManagerName's new manager. If $SelfListedAsManagerName does not report to anyone, leave blank and hit Enter"
    echo ""

    if ($SelfListedEmployeeNewManagerUsername -eq [string]::empty)
    {
        Get-ADUser -Filter {SamAccountName -eq $SelfListedAsManagerUsername} | Set-ADUser -Credential $Credential -Clear Manager

        if ($? -eq $True)
        {
            echo "Cleared $SelfListedAsManagerName`'s manager"
        }
    }

    else {
    $SelfListedEmployeeNewManagerObject = $(Get-ADUser -Filter {SamAccountName -eq $SelfListedEmployeeNewManagerUsername})
    $SelfListedEmployeeNewManagerName = $(($SelfListedEmployeeNewManagerObject | Select Name -ExpandProperty Name | Out-String).Trim())

    Get-ADUser -Filter {SamAccountName -eq $SelfListedAsManagerUsername} | Set-ADUser -Credential $Credential -Manager $SelfListedEmployeeNewManagerObject

    if ($? -eq $True)
    {
        echo "Updated $SelfListedAsManagerName`'s manager to $SelfListedEmployeeNewManagerName"
    }
    
    echo ""
    Read-Host -Prompt "Press Enter to exit"
    exit
    }
}
