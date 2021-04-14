############################################################
# Compares on-prem AD with Azure AD and lists out devices that exist on one side but not the other (searches by device ID)
############################################################

Connect-AzureAD # | Out-Null

# Get current date to create unique filename to save output
$date = $(Get-Date -Format "yyyyMMdd")

echo "==========================================" >> ([Environment]::GetFolderPath("Desktop")+"\device-report-$date.txt")
echo "Devices in Azure AD but not in on-prem AD" >> ([Environment]::GetFolderPath("Desktop")+"\device-report-$date.txt")
echo "==========================================" >> ([Environment]::GetFolderPath("Desktop")+"\device-report-$date.txt")

$aad_devices = $(Get-AzureADDevice -All $True -Filter "startswith(DeviceOSType,'Windows')" | Select DisplayName, DeviceId)

foreach($device in $aad_devices)
{
	$guid = $(($device | Select DeviceId -ExpandProperty DeviceId | Out-String).Trim())
	$ErrorActionPreference = ‘SilentlyContinue’ # Suppress non-terminating error
	Get-ADComputer -Identity "$guid" > $null
	if ($? -eq $False)
	{
		echo "$(($device | Select Name -ExpandProperty DisplayName | Out-String).Trim())" >> ([Environment]::GetFolderPath("Desktop")+"\device-report-$date.txt")
	}
}

echo "==========================================" >> ([Environment]::GetFolderPath("Desktop")+"\device-report-$date.txt")
echo "Devices in on-prem AD but not in Azure AD" >> ([Environment]::GetFolderPath("Desktop")+"\device-report-$date.txt")
echo "==========================================" >> ([Environment]::GetFolderPath("Desktop")+"\device-report-$date.txt")


$ad_devices = $(Get-ADComputer -Filter * | Select Name,ObjectGUID)

foreach ($device in $ad_devices)
{
	# For some reason, -ExpandProperty does not hide table headers, so piping it through ft -HideTableHeaders to hide
	$guid = $(($device | Select ObjectGUID -ExpandProperty ObjectGUID | ft -HideTableHeaders | Out-String).Trim())

	# Weird -Filter syntax due to Microsoft being stupid: https://github.com/Azure/azure-docs-powershell-azuread/issues/216#issuecomment-633943632
	# For some reason, the exit status returns $True even if the device cannot be found, so we're counting the number of lines in the output
	# to figure out whether a device actually exists
	$exists_in_aad = $((Get-AzureADDevice -Filter "DeviceID eq guid`'$guid`'" | Select ObjectId -ExpandProperty ObjectId | Measure-Object -Line | Select Lines -ExpandProperty Lines | Out-String).Trim())

	if (-not($exists_in_aad -eq "1"))
	{
		echo "$(($device | Select Name -ExpandProperty Name | Out-String).Trim())" >> ([Environment]::GetFolderPath("Desktop")+"\device-report-$date.txt")
	}
}
