##################################################
# This script searches through the device name column in Azure AD and searches for duplicate iOS devices.
# Results are saved to a text file on your desktop.
# 
# Output filename: duplicate aad-ios-devices-DATE.txt
# Output format: DEVICE NAME (# OF TIMES DUPLICATED)
#  
# Sample output:
# ***************
# YXX0XT78XY9X (2)
# XX0XY1XYX2XX (4)
# X0XX234XYXYX (3)
# User deleted for this device (3)
# ***************
#
# INSTRUCTIONS
# 1. Do not run this script as administrator. This script only reads from Azure AD and does not require elevated privileges
# 2. The script will prompt you for your O365 credentials. Login with your UPN
#
# CAVEATS
# 1. Does not check for duplicate Windows device
##################################################

# Check if AzureAD cmdlet is installed
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
$AuthenticationStatus = $False
while (-not $AuthenticationStatus)
{
    Connect-AzureAD -errorAction SilentlyContinue *> $null

    $AuthenticationStatus = $?

    if ($AuthenticationStatus)
    {
        echo "Authentication successful"
        echo "Processing... Please wait..."
    }
    else
    {
        echo "Authentication failed/cancelled"
        Read-Host -Prompt "Press Enter to exit"
        exit
    }
}

# Get current date to create unique filename to save output
$Date = $(Get-Date -Format "yyyyMMdd")

$AADDevices = $(Get-AzureADDevice -All $True -Filter "startswith(DeviceOSType,'iOS')") + $(Get-AzureADDevice -All $True -Filter "startswith(DeviceOSType,'iPhone')") + $(Get-AzureADDevice -All $True -Filter "startswith(DeviceOSType,'iPad')")
$UniqueDevices = $($AADDevices | Sort-Object "DisplayName" | Select DisplayName | Get-Unique -AsString)

foreach($Device in $UniqueDevices)
{
    $DeviceName = $(($Device | Select DisplayName -ExpandProperty DisplayName | Out-String).Trim())
    $Count = $((Get-AzureADDevice -SearchString "$DeviceName" | Measure-Object | Select Count -ExpandProperty Count | Out-String).Trim())

    if ([int]$Count -gt 1)
    {
        echo "$(($Device | Select DisplayName -ExpandProperty DisplayName | Out-String).Trim()) `($Count`)" >> ([Environment]::GetFolderPath("Desktop")+"\duplicate-aad-ios-devices-$Date.txt")
    }
}

echo "Results have been compiled and saved to `"duplicate-aad-ios-devices-$Date.txt`" on your desktop"
Read-Host -Prompt "Press Enter to exit"
exit
