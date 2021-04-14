$Credential = $host.ui.PromptForCredential("Need credentials", "Please enter your user name and password.", "", "NetBiosUserName")
$CurrentManager = Read-Host "Enter current manager's username"

echo "Processing... Please wait..."

$DirectReports = $(Get-ADUser -Filter * -Properties * | Select Name, SamAccountName, @{n='ManagerUsername';e={(Get-ADUser $_.Manager).SamAccountName}} | where-object {$_.ManagerUsername -contains "$CurrentManager"})
$DirectReportsCount = $($DirectReports | Measure-Object | Select Count -ExpandProperty Count)

echo ""
echo "Found direct reports ($DirectReportsCount):"
Write-Host ($DirectReports | Select Name, SamAccountName | Out-String)

$NewManager = Read-Host "If this looks correct and you'd like to proceed with the update, enter the username of the new manager"
$NewManagerObject = $(Get-ADUser -Filter {SamAccountName -eq $NewManager})

$SelfListedAsManager = $False

foreach ($Employee in $DirectReports)
{
	$EmployeeUsername = $(($Employee | Select SamAccountName -ExpandProperty SamAccountName | Out-String).Trim())
	$EmployeeName = $(($Employee | Select Name -ExpandProperty Name | Out-String).Trim())
	Get-ADUser -Filter {SamAccountName -eq $EmployeeUsername} | Set-ADUser -Credential $Credential -Manager $NewManagerObject

	echo "Updated manager for $EmployeeName"

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

	$SelfListedEmployeeNewManagerUsername = Read-Host "It seems like $SelfListedAsManagerName ($SelfListedAsManagerUsername) was promoted from within the department and is now listed as their own manager. Enter $SelfListedAsManagerName's new manager. If $SelfListedAsManagerName does not report to anyone, leave blank and hit Enter"
	$SelfListedEmployeeNewManagerObject = $(Get-ADUser -Filter {SamAccountName -eq $SelfListedEmployeeNewManagerUsername})

	Get-ADUser -Filter {SamAccountName -eq $SelfListedAsManagerUsername} | Set-ADUser -Credential $Credential -Manager $SelfListedEmployeeNewManagerObject

	echo "Updated manager for $SelfListedAsManagerName"
}
