Configuration Main
{

Param ( [string] $nodeName, [string] $newPwd, [string] $newUsrPwd, [string] $serviceAccount )

Import-DscResource -ModuleName PSDesiredStateConfiguration, cChoco, xStorage, xDSCFirewall, xComputerManagement, xPendingReboot, xNetworking, xSystemSecurity, cSecurityOptions



#install-module cSecurityOptions
#Import-Module cSecurityOptions

Node $nodeName
  {
    $FullServiceAccount = -join($serviceAccount, "\mfservice")

	LocalConfigurationManager 
        {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }
	
	   Service WindowsFirewall
        {
            Name = "MPSSvc"
            StartupType = "Automatic"
            State = "Running"
        }

        xDSCFirewall Public
        {
            Ensure = "Absent"
            Zone = "Public"
            DependsOn = "[Service]WindowsFirewall"
        }

        xDSCFirewall Private
        {
            Ensure = "Absent"
            Zone = "Private"
            DependsOn = "[Service]WindowsFirewall"
        }
         xDSCFirewall Domain
        {
            Ensure = "Absent"
            Zone = "Domain"
            DependsOn = "[Service]WindowsFirewall"
        }

        xIEEsc EnableIEEscAdmin
        {
            IsEnabled = $False
            UserRole = "Administrators"
        }
                
        xIEEsc EnableIEEscUser
        {
            IsEnabled = $True
            UserRole = "Users"
        }


        File FolderC
            {
                Type = "Directory"
                Ensure = "Present"
                DestinationPath = "C:\filestore"
				
             }

        xWaitforDisk Disk2
			{
				DiskId = 2
				RetryIntervalSec = 60
				RetryCount = 60
			} 


        xDisk EVolume
			{
				DiskId = 2
				DriveLetter = 'F'
				FSLabel = 'Logs'
				FSFormat = 'NTFS'
                DependsOn = "[xWaitforDisk]Disk2" 
			}
		
	    File FolderE
            {
                Type = "Directory"
                Ensure = "Present"
                DestinationPath = "F:\SQLLogs"
                DependsOn = "[xDisk]EVolume" 
				
             }
       
	    xWaitforDisk Disk3
			{
				DiskId = 3
				RetryIntervalSec = 60
				RetryCount = 60
			} 
		
	    xDisk FVolume
			{
				DiskId = 3
				DriveLetter = 'G'
				FSLabel = 'Data'
				FSFormat = 'NTFS'
                DependsOn = "[xWaitforDisk]Disk3"
			}
        File FolderF
            {
                Type = "Directory"
                Ensure = "Present"
                DestinationPath = "G:\SQLData"
                DependsOn = "[xDisk]FVolume"
				
             }

    	       
	    xWaitforDisk Disk4
			{
				DiskId = 4
				RetryIntervalSec = 60
				RetryCount = 60
			} 
	    xDisk GVolume
			{
				DiskId = 4
				DriveLetter = 'H'
				FSLabel = 'APPS'
				FSFormat = 'NTFS'
                DependsOn = "[xWaitforDisk]Disk4"
			}
		File FolderG
            {
                Type = "Directory"
                Ensure = "Present"
                DestinationPath = "H:\Apps"
                DependsOn = "[xDisk]GVolume"
				
             }

        xWaitforDisk Disk5
			{
				DiskId = 5
				RetryIntervalSec = 60
				RetryCount = 60
			} 
		xDisk HVolume
			{
				DiskId = 5
				DriveLetter = 'I'
				FSLabel = 'Backups'
				FSFormat = 'NTFS'
                DependsOn = "[xWaitforDisk]Disk5"
			}
		File FolderH
            {
                Type = "Directory"
                Ensure = "Present"
                DestinationPath = "I:\Backups"
                DependsOn = "[xDisk]HVolume"
				
             }
        Environment EnvironmentSQLSA
            {
                Ensure = "Present"
                Name = "SQLPASS"
                Value = $newPwd
            }
        Environment EnvironmentSQLUserPass
            {
                Ensure = "Present"
                Name = "SQLUSERPASS"
                Value = $newUsrPwd
            }        
        Script UpdateSQL
            {
                
                setscript = { . 'C:\Packages\Plugins\Microsoft.Powershell.DSC\2.83.0.0\DSCWork\TMSBuildDSC.0\AmendSQL.ps1' }

                testscript = { $false }

                getscript = { @{ Result = ( Get-Content "C:\Packages\Plugins\Microsoft.Powershell.DSC\2.83.0.0\DSCWork\TMSBuildDSC.0\AmendSQL.ps1") } }
                DependsOn = "[File]FolderH"
            }
             
        UserRightsAssignment AllowLogonRight
            {
                Privilege = 'SeInteractiveLogonRight'
                Ensure = 'Present'
                Identity = 'Administrators', 'Users', 'Backup Operators', 'mfservice'
                DependsOn = "[Script]UpdateSQL"
            }
        UserRightsAssignment CreateTokenObject
            {
                Privilege = 'SeCreateTokenPrivilege'
                Ensure = 'Present'
                Identity = 'mfservice'
                DependsOn = "[Script]UpdateSQL"
            }
        UserRightsAssignment AllowLogonAsService
            {
                Privilege = 'SeServiceLogonRight'
                Ensure = 'Present'
                Identity = 'ALL SERVICES', 'mfservice'
                DependsOn = "[Script]UpdateSQL"
            }
        UserRightsAssignment ReplaceProcessLevelToken
            {
                Privilege = 'SeAssignPrimaryTokenPrivilege'
                Ensure = 'Present'
                Identity = 'LOCAL SERVICE', 'NETWORK SERVICE', 'mfservice'
                DependsOn = "[Script]UpdateSQL"
            }
        UserRightsAssignment AllowLogonAsBatchJob
            {
                Privilege = 'SeBatchLogonRight'
                Ensure = 'Present'
                Identity = 'Administrators', 'Backup Operators', 'Performance Log Users', 'mfsqlbackups'
                DependsOn = "[Script]UpdateSQL"
            }



        $IISFeatures = "Web-WebServer","Web-Common-Http","Web-Default-Doc","Web-Dir-Browsing","Web-Http-Errors","Web-Static-Content","Web-Http-Redirect","Web-DAV-Publishing","Web-Health","Web-Http-Logging","Web-Custom-Logging","Web-Log-Libraries","Web-ODBC-Logging","Web-Request-Monitor","Web-Http-Tracing","Web-Performance","Web-Stat-Compression","Web-Dyn-Compression","Web-Security","Web-Filtering","Web-Basic-Auth","Web-CertProvider","Web-Client-Auth","Web-Digest-Auth","Web-Cert-Auth","Web-IP-Security","Web-URL-Auth","Web-Windows-Auth","Web-App-Dev","Web-Net-Ext","Web-Net-Ext45","Web-AppInit","Web-ASP","Web-Asp-Net","Web-Asp-Net45","Web-CGI","Web-ISAPI-Ext","Web-ISAPI-Filter","Web-Includes","Web-WebSockets","Web-Mgmt-Tools","Web-Mgmt-Console","Web-Mgmt-Compat","Web-Metabase","Web-Lgcy-Mgmt-Console","Web-Lgcy-Scripting","Web-WMI","Web-Scripting-Tools","Web-Mgmt-Service"
        Install-WindowsFeature -Name $IISFeatures
        
        Enable-WindowsOptionalFeature -Online -FeatureName "WCF-HTTP-Activation45" -All
        Enable-WindowsOptionalFeature -Online -FeatureName "WCF-HTTP-Activation" -All

       
 <# This commented section represents an example configuration that can be updated as required.
    WindowsFeature WebManagementConsole
    {
      Name = "Web-Mgmt-Console"
      Ensure = "Present"
    }
    WindowsFeature WebManagementService
    {
      Name = "Web-Mgmt-Service"
      Ensure = "Present"
    }
    WindowsFeature ASPNet45
    {
      Name = "Web-Asp-Net45"
      Ensure = "Present"
    }
    WindowsFeature HTTPRedirection
    {
      Name = "Web-Http-Redirect"
      Ensure = "Present"
    }
    WindowsFeature CustomLogging
    {
      Name = "Web-Custom-Logging"
      Ensure = "Present"
    }
    WindowsFeature LogginTools
    {
      Name = "Web-Log-Libraries"
      Ensure = "Present"
    }
    WindowsFeature RequestMonitor
    {
      Name = "Web-Request-Monitor"
      Ensure = "Present"
    }
    WindowsFeature Tracing
    {
      Name = "Web-Http-Tracing"
      Ensure = "Present"
    }
    WindowsFeature BasicAuthentication
    {
      Name = "Web-Basic-Auth"
      Ensure = "Present"
    }
    WindowsFeature WindowsAuthentication
    {
      Name = "Web-Windows-Auth"
      Ensure = "Present"
    }
    WindowsFeature ApplicationInitialization
    {
      Name = "Web-AppInit"
      Ensure = "Present"
    }
    Script DownloadWebDeploy
    {
        TestScript = {
            Test-Path "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
        }
        SetScript ={
            $source = "https://download.microsoft.com/download/0/1/D/01DC28EA-638C-4A22-A57B-4CEF97755C6C/WebDeploy_amd64_en-US.msi"
            $dest = "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
            Invoke-WebRequest $source -OutFile $dest
        }
        GetScript = {@{Result = "DownloadWebDeploy"}}
        DependsOn = "[WindowsFeature]WebServerRole"
    }
    Package InstallWebDeploy
    {
        Ensure = "Present"  
        Path  = "C:\WindowsAzure\WebDeploy_amd64_en-US.msi"
        Name = "Microsoft Web Deploy 3.6"
        ProductId = "{ED4CC1E5-043E-4157-8452-B5E533FE2BA1}"
        Arguments = "ADDLOCAL=ALL"
        DependsOn = "[Script]DownloadWebDeploy"
    }
    Service StartWebDeploy
    {                    
        Name = "WMSVC"
        StartupType = "Automatic"
        State = "Running"
        DependsOn = "[Package]InstallWebDeploy"
    } #>
  }
}