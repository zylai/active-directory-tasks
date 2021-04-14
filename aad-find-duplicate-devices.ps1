############################################################
# Searches through iOS and iPadOS devices in AAD and lists out duplicates (by comparing device names)
############################################################

# Check if Msol cmdlet is installed
if (-Not (Get-Command -Module AzureAD -errorAction SilentlyContinue)) {
	echo "AzureAD is not installed. This script requires the AzureAD cmdlet to work"
	echo 'To install this module, run the following command in PowerShell as administrator (select "[A] Yes to All" when prompted):'
	echo ""
	echo "Install-Module AzureAD"
	echo ""
	echo "More info: https://docs.microsoft.com/en-us/microsoft-365/enterprise/connect-to-microsoft-365-powershell?view=o365-worldwide"
	echo ""
	Read-Host -Prompt "Press Enter to exit"
	exit
}

# Prompt for authentication and connect to Azure AD
$authentication_status = $False
while (-not $authentication_status)
{
	Connect-AzureAD -errorAction SilentlyContinue

	$authentication_status = $?

	if ($authentication_status)
	{
		echo "Authentication successful"
	} 
	else
	{
		exit
	}
}


# Get current date to create unique filename to save output
$date = $(Get-Date -Format "yyyyMMdd")

$aad_devices = $(Get-AzureADDevice -All $True -Filter "startswith(DeviceOSType,'iOS')") + $(Get-AzureADDevice -All $True -Filter "startswith(DeviceOSType,'iPhone')")
$unique_devices = $($aad_devices | Sort-Object "DisplayName" | Select DisplayName | Get-Unique -AsString)

foreach($device in $unique_devices)
{
	$device_name = $(($device | Select DisplayName -ExpandProperty DisplayName | Out-String).Trim())
	$count = $((Get-AzureADDevice -SearchString "$device_name" | Measure-Object | Select Count -ExpandProperty Count | Out-String).Trim())

	if ([int]$count -gt 1)
	{
		echo "$(($device | Select DisplayName -ExpandProperty DisplayName | Out-String).Trim())"
	}
}
