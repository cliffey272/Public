Param ( [string] $newPwd, [string] $newUsrPwd )


# import the SQLPS module
import-module SqlPS -DisableNameChecking

# obtain environment variables
$newPwd = Get-ItemProperty -Path "HKLM:\SYSTEM\ControlSet001\Control\Session Manager\Environment" -Name "SQLPASS" | Select-Object -ExpandProperty SQLPASS
$newUsrPwd = Get-ItemProperty -Path "HKLM:\SYSTEM\ControlSet001\Control\Session Manager\Environment" -Name "SQLUSERPASS" | Select-Object -ExpandProperty SQLUSERPASS

# connect to SQL server and amend the logon mode
$SQLserver = hostname
# Connect to the instance using SMO
$s = new-object ('Microsoft.SqlServer.Management.Smo.Server') $SQLserver
[string]$nm = $s.Name
[string]$mode = $s.Settings.LoginMode
write-output "Instance Name: $nm"
write-output "Login Mode: $mode"
# Change to Mixed Mode
$s.Settings.LoginMode = [Microsoft.SqlServer.Management.SMO.ServerLoginMode]::Mixed
# Make the changes
$s.Alter()
# Restart the SQL service
net stop "MSSQLSERVER"
net start "MSSQLSERVER"

# SQL Queries
$query1 = "ALTER LOGIN sa ENABLE"
$query2 = "ALTER LOGIN sa WITH PASSWORD = '$newPwd'"
$ChangeSQLMemory = "DECLARE @maxMem INT = 2048; EXEC sp_configure 'show advanced options', 1 RECONFIGURE; EXEC sp_configure 'max server memory', @maxMem RECONFIGURE; DECLARE @minMem INT = 2048; EXEC sp_configure 'show advanced options', 1 RECONFIGURE; EXEC sp_configure 'min server memory', @minMem RECONFIGURE;"
$ChangeDBQueryFull = "EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE' , N'Software\Microsoft\MSSQLServer\MSSQLServer' , N'DefaultData' , REG_SZ , N'G:\SQLData'; EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE' , N'Software\Microsoft\MSSQLServer\MSSQLServer' , N'DefaultLog' , REG_SZ , N'F:\SQLLogs'; EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE' , N'Software\Microsoft\MSSQLServer\MSSQLServer' , N'BackupDirectory' , REG_SZ , N'I:\Backup';"
$CreateDBUser =  -join("CREATE LOGIN mfuser WITH PASSWORD=N'", $newUsrPwd, "', DEFAULT_DATABASE=master, CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF;")
$CreateDB = "CREATE DATABASE mfdata COLLATE SQL_Latin1_General_CP1_CI_AS"
$ChangeDBOwner = "EXEC sp_changedbowner 'mfuser'"

# SQL commands to enable SA, reset its password and amend the memory usage / directory locations
Invoke-Sqlcmd -ServerInstance $SQLserver -Database 'MASTER' -Query $query1
Invoke-Sqlcmd -ServerInstance $SQLserver -Database 'MASTER' -Query $query2
Invoke-Sqlcmd -ServerInstance $SQLserver -Database 'MASTER' -Query $ChangeDBQueryFull
Invoke-Sqlcmd -ServerInstance $SQLserver -Database 'MASTER' -Query $ChangeSQLMemory

# Restart the SQL service
net stop "MSSQLSERVER"
net start "MSSQLSERVER"

# Create DB user, DB and amend ownership with 10 second sleeps
Start-Sleep -s 10
Invoke-Sqlcmd -ServerInstance $SQLserver -Database 'MASTER' -Query $CreateDBUser
Start-Sleep -s 10
Invoke-Sqlcmd -ServerInstance $SQLserver -Database 'MASTER' -Query $CreateDB
Start-Sleep -s 10
Invoke-Sqlcmd -ServerInstance $SQLserver -Database 'mfdata' -Query $ChangeDBOwner


# remove environment variables
Get-Item -Path "HKLM:\SYSTEM\ControlSet001\Control\Session Manager\Environment" | Remove-ItemProperty -Name SQLPASS
Get-Item -Path "HKLM:\SYSTEM\ControlSet001\Control\Session Manager\Environment" | Remove-ItemProperty -Name SQLUSERPASS
        
# Amend variable for password and convert to secure string
$newUsrPwd = -join($newUsrPwd, "$")
$LocalUserPassword = ConvertTo-SecureString $newUsrPwd -AsPlainText -Force

# Create local admin user mfservice
New-LocalUser "mfservice" -Password $LocalUserPassword -FullName "mfservice" -Description "MF Service Account" -PasswordNeverExpires -UserMayNotChangePassword
Add-LocalGroupMember -Group "Administrators" -Member "mfservice"

# Create local user for SQL Backups
New-LocalUser "mfsqlbackups" -Password $LocalUserPassword -FullName "mfsqlbackups" -Description "MF SQL Backup Account" -PasswordNeverExpires -UserMayNotChangePassword


# Create SQL logon for mfsqlbackups user and grant sysadmin rights

$localuser = -join($env:COMPUTERNAME, "\mfsqlbackups")
$localuser = "`"$localuser`""

$CreateDBBackupUser =  -join("CREATE LOGIN ", $localuser, " FROM WINDOWS")
$DBBackupUserRole =  -join("ALTER SERVER ROLE sysadmin ADD MEMBER ", $localuser)
Invoke-Sqlcmd -ServerInstance $SQLserver -Database 'MASTER' -Query $CreateDBBackupUser
Invoke-Sqlcmd -ServerInstance $SQLserver -Database 'MASTER' -Query $DBBackupUserRole


# Change ACL on I:\Backups for SQL backup user


# this is performed to allow powershell to discover the drives correctly - powershell bug that blocks Get-ACL from working correctly
Get-PSDrive


# Sets the permission on the folder I:\Backup to Full controll against the sql user

$localuser = -join($env:COMPUTERNAME, "\mfsqlbackups")

$path="I:\"
$DirArray = Get-ChildItem $Path -Recurse 

ForEach ($i in $DirArray)
 {
        
        $acl = Get-Acl $i.FullName
        $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($localuser,"FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.SetAccessRule($AccessRule)
        Set-Acl $i.FullName $acl
        $Error.Clear()

}

cd C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.10.9\Downloads\0\
.\ndp48-x86-x64-allos-enu.exe /q /norestart -Wait
