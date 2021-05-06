##################################################
# This script searches through AD and Azure AD and looks for devices (by device ID) that only exists on one side.
# Results are saved to a text file on your desktop.
# 
# Output filename: cross-check-ad-aad-DATE.txt
# Output format: HOSTNAME (DEVICE ID) -OR- HOSTNAME (PUBLISHED AT)
#  
# Sample output:
# ***************
# ==========================================
# Devices in Azure AD but not in on-prem AD
# ==========================================
# A123456 (a996d277-2e1a-4f78-a13b-b5ae65a00401)
# B123456 (2f35a359-6dce-403e-9fbc-7a0098b92bce)
#
# ==========================================
# Devices in on-prem AD but not in Azure AD
# ==========================================
# DC (CN=DC,OU=Domain Controllers,DC=company,DC=org)
# MAILSERVER (CN=MAILSERVER,OU=Servers,DC=company,DC=org)
# PHONESERVER (CN=PHONESERVER,OU=Servers,DC=company,DC=org)
# ***************
#
# INSTRUCTIONS
# 1. Do not run this script as administrator. This script only reads from Azure AD and does not require elevated privileges
# 2. The script will prompt you for your O365 credentials. Login with your UPN
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

echo "==========================================" >> ([Environment]::GetFolderPath("Desktop")+"\cross-check-ad-aad-$Date.txt")
echo "Devices in Azure AD but not in on-prem AD" >> ([Environment]::GetFolderPath("Desktop")+"\cross-check-ad-aad-$Date.txt")
echo "==========================================" >> ([Environment]::GetFolderPath("Desktop")+"\cross-check-ad-aad-$Date.txt")

$AADDevices = $(Get-AzureADDevice -All $True -Filter "startswith(DeviceOSType,'Windows')" | Select DisplayName, DeviceId)

foreach($Device in $AADDevices)
{
    $GUID = $(($Device | Select DeviceId -ExpandProperty DeviceId | Out-String).Trim())
    $ErrorActionPreference = ‘SilentlyContinue’ # Suppress non-terminating error
    Get-ADComputer -Identity "$GUID" *> $null
    if ($? -eq $False)
    {
        echo "$(($Device | Select Name -ExpandProperty DisplayName | Out-String).Trim()) `($(($Device | Select DeviceId -ExpandProperty DeviceId | Out-String).Trim())`)" >> ([Environment]::GetFolderPath("Desktop")+"\cross-check-ad-aad-$Date.txt")
    }
}

echo "" >> ([Environment]::GetFolderPath("Desktop")+"\cross-check-ad-aad-$Date.txt")
echo "==========================================" >> ([Environment]::GetFolderPath("Desktop")+"\cross-check-ad-aad-$Date.txt")
echo "Devices in on-prem AD but not in Azure AD" >> ([Environment]::GetFolderPath("Desktop")+"\cross-check-ad-aad-$Date.txt")
echo "==========================================" >> ([Environment]::GetFolderPath("Desktop")+"\cross-check-ad-aad-$Date.txt")


$ADDevices = $(Get-ADComputer -Filter * | Select Name,ObjectGUID,DistinguishedName)

foreach ($Device in $ADDevices)
{
    # For some reason, -ExpandProperty does not hide table headers, so piping it through ft -HideTableHeaders to hide
    $GUID = $(($Device | Select ObjectGUID -ExpandProperty ObjectGUID | ft -HideTableHeaders | Out-String).Trim())

    # Weird -Filter syntax: https://github.com/Azure/azure-docs-powershell-azuread/issues/216#issuecomment-633943632
    # For some reason, the exit status returns $True even if the device cannot be found, so we're counting the number of lines
    # in the output to figure out whether a device actually exists
    $ExistsInAAD = $((Get-AzureADDevice -Filter "DeviceID eq guid`'$GUID`'" | Select ObjectId -ExpandProperty ObjectId | Measure-Object -Line | Select Lines -ExpandProperty Lines | Out-String).Trim())

    if (-not($ExistsInAAD -eq "1"))
    {
        echo "$(($Device | Select Name -ExpandProperty Name | Out-String).Trim()) `($(($Device | Select DistinguishedName -ExpandProperty DistinguishedName | Out-String).Trim())`)" >> ([Environment]::GetFolderPath("Desktop")+"\cross-check-ad-aad-$Date.txt")
    }
}

echo "Results have been compiled and saved to `"cross-check-ad-aad-$Date.txt`" on your desktop"
Read-Host -Prompt "Press Enter to exit"
exit
