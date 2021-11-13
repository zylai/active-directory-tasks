# Self-elevate the script if required
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
 if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
  $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
  Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
  Exit
 }
}

echo "This script performs the following actions on a machine specified by the user:"
echo "`t 1. Disables the computer account in AD"
echo "`t 2. Moves the computer account into the Disabled Computers OU"
echo "`t 3. Deletes the computer from SCCM"
echo ""
Read-Host “Press ENTER to continue...”

echo "Connecting to SCCM..."

Import-Module "C:\Program Files (x86)\Microsoft Endpoint Manager\AdminConsole\bin\ConfigurationManager.psd1"

$sccmConnectCount = 0
$sccmConnectMaxTries = 3

while ($True)
{
    try
    {
        New-PSDrive -Name XXX -PSProvider "AdminUI.PS.Provider\CMSite" -Root "xxx.contoso.corp" -Description "SCCM Site" -ErrorAction Stop
        break
    }
    catch
    {
        cd C:\WINDOWS\system32
        Remove-PSDrive -Name SMS -ErrorAction SilentlyContinue

        $sccmConnectCount++

        Start-Sleep -s 3

        if ($sccmConnectCount -ge $sccmConnectMaxTries)
        {
            Write-Host "Unable to connect to SCCM" -ForegroundColor red
            Read-Host "Press any key to exit..."
            exit
        }
    }
}

cd SMS:

echo ""

while ($True)
{
    echo ""
    $targetDevice = Read-Host "Enter the machine name (or nothing to exit)"

    if ($targetDevice -eq "")
    {
        break
    }

    try
    {
        $targetDeviceObject = $(Get-ADComputer "$targetDevice" -ErrorAction Stop)
        try
        {
            Disable-ADAccount $targetDeviceObject -ErrorAction Stop
            Write-Host "Successfully disabled $targetDevice in AD" -ForegroundColor green
            try
            {
                Move-ADObject $targetDeviceObject -TargetPath "OU=xxx,DC=contoso,DC=corp" -ErrorAction Stop
                Write-Host "Successfully moved $targetDevice to Disabled Computers OU" -ForegroundColor green
            }
            catch
            {
                Write-Host "Unable to move $targetDevice to Disabled Computers OU" -ForegroundColor red
            }
        }
        catch
        {
            Write-Host "Unable to disable $targetDevice in AD" -ForegroundColor red
        }
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
    {
        Write-Host "Unable to find $targetDevice in AD" -ForegroundColor yellow
    }
    catch
    {
        Write-Host "Unable to move/disable $targetDevice in AD" -ForegroundColor red
    }

    # Remove device from SCCM
    try
    {
        Remove-CMDevice "$targetDevice" -force -ErrorAction Stop
        Write-Host "Successfully removed $targetDevice from SCCM" -ForegroundColor green
    }
    catch [System.Management.Automation.ItemNotFoundException]
    {
        Write-Host "Unable to find $targetDevice in SCCM" -ForegroundColor yellow
    }
    catch
    {
        Write-Host "Unable to remove $targetDevice from SCCM" -ForegroundColor red
    }

}

cd C:\WINDOWS\system32
Remove-PSDrive -Name SMS

echo ""
echo "Bye!"
echo ""
Read-Host "Press any key to exit..."
