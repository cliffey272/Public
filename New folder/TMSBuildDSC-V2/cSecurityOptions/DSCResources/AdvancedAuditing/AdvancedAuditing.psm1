function GetConfigValue
{
    param($pol_number)
    switch ($pol_number)
    {
    "No Auditing" {return " /success:disable /failure:disable"}
    "Success" {return " /success:enable /failure:disable"}
    "Failure" {return " /success:disable /failure:enable"}
    "Success and Failure" {return " /success:enable /failure:enable"}
    }
}

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet("System;IPsec Driver","System;System Integrity","System;Security System Extension","System;Security State Change","System;Other System Events","Logon/Logoff;Network Policy Server","Logon/Logoff;Other Logon/Logoff Events","Logon/Logoff;Special Logon","Logon/Logoff;IPsec Extended Mode","Logon/Logoff;IPsec Quick Mode","Logon/Logoff;IPsec Main Mode","Logon/Logoff;Account Lockout","Logon/Logoff;Logoff","Logon/Logoff;Logon","Logon/Logoff;User / Device Claims","Object Access;SAM","Object Access;Kernel Object","Object Access;Registry","Object Access;Application Generated","Object Access;Handle Manipulation","Object Access;File Share","Object Access;Filtering Platform Packet Drop","Object Access;Filtering Platform Connection","Object Access;Other Object Access Events","Object Access;Detailed File Share","Object Access;Removable Storage","Object Access;Central Policy Staging","Object Access;Certification Services","Object Access;File System","Privilege Use;Other Privilege Use Events","Privilege Use;Non Sensitive Privilege Use","Privilege Use;Sensitive Privilege Use","Detailed Tracking;RPC Events","Detailed Tracking;DPAPI Activity","Detailed Tracking;Process Termination","Detailed Tracking;Process Creation","Policy Change;Audit Policy Change","Policy Change;MPSSVC Rule-Level Policy Change","Policy Change;Filtering Platform Policy Change","Policy Change;Authorization Policy Change","Policy Change;Authentication Policy Change","Policy Change;Other Policy Change Events","Account Management;Security Group Management","Account Management;Distribution Group Management","Account Management;Other Account Management Events","Account Management;Application Group Management","Account Management;Computer Account Management","Account Management;User Account Management","DS Access;Directory Service Changes","DS Access;Directory Service Replication","DS Access;Directory Service Access","DS Access;Detailed Directory Service Replication","Account Logon;Other Account Logon Events","Account Logon;Kerberos Service Ticket Operations","Account Logon;Credential Validation","Account Logon;Kerberos Authentication Service")]
        [System.String]
        $Category,

        [parameter(Mandatory = $true)]
        [ValidateSet("No Auditing","Success","Failure","Success and Failure")]
        [System.String]
        $AuditLevel
    )
    $ErrorActionPreference = 'Stop'
    #Write-Verbose "Use this cmdlet to deliver information about command processing."

    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."
    $categoryParts = $Category.split(";")
    $majorcategory = $categoryParts[0]
    $minorcategory = $categoryParts[1]

    $ps = new-object System.Diagnostics.Process
    $ps.StartInfo.Filename = "auditpol.exe"
    $ps.StartInfo.Arguments = " /get /category:`"$majorcategory`" /r"
    $ps.StartInfo.RedirectStandardOutput = $True
    $ps.StartInfo.UseShellExecute = $false
    [void]$ps.start()
    [void]$ps.WaitForExit('10')
    [string] $Out = $ps.StandardOutput.ReadToEnd();
    $curr_audit_pol_setting = $Out | ConvertFrom-CSV | Where-Object {$_.Subcategory -eq $minorcategory}
    $curr_value = $curr_audit_pol_setting.'Inclusion Setting' 

    $returnValue = @{
                     Category = $Category
                     AuditLevel = $curr_value
                    }

    $returnValue
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet("System;IPsec Driver","System;System Integrity","System;Security System Extension","System;Security State Change","System;Other System Events","Logon/Logoff;Network Policy Server","Logon/Logoff;Other Logon/Logoff Events","Logon/Logoff;Special Logon","Logon/Logoff;IPsec Extended Mode","Logon/Logoff;IPsec Quick Mode","Logon/Logoff;IPsec Main Mode","Logon/Logoff;Account Lockout","Logon/Logoff;Logoff","Logon/Logoff;Logon","Logon/Logoff;User / Device Claims","Object Access;SAM","Object Access;Kernel Object","Object Access;Registry","Object Access;Application Generated","Object Access;Handle Manipulation","Object Access;File Share","Object Access;Filtering Platform Packet Drop","Object Access;Filtering Platform Connection","Object Access;Other Object Access Events","Object Access;Detailed File Share","Object Access;Removable Storage","Object Access;Central Policy Staging","Object Access;Certification Services","Object Access;File System","Privilege Use;Other Privilege Use Events","Privilege Use;Non Sensitive Privilege Use","Privilege Use;Sensitive Privilege Use","Detailed Tracking;RPC Events","Detailed Tracking;DPAPI Activity","Detailed Tracking;Process Termination","Detailed Tracking;Process Creation","Policy Change;Audit Policy Change","Policy Change;MPSSVC Rule-Level Policy Change","Policy Change;Filtering Platform Policy Change","Policy Change;Authorization Policy Change","Policy Change;Authentication Policy Change","Policy Change;Other Policy Change Events","Account Management;Security Group Management","Account Management;Distribution Group Management","Account Management;Other Account Management Events","Account Management;Application Group Management","Account Management;Computer Account Management","Account Management;User Account Management","DS Access;Directory Service Changes","DS Access;Directory Service Replication","DS Access;Directory Service Access","DS Access;Detailed Directory Service Replication","Account Logon;Other Account Logon Events","Account Logon;Kerberos Service Ticket Operations","Account Logon;Credential Validation","Account Logon;Kerberos Authentication Service")]
        [System.String]
        $Category,

        [parameter(Mandatory = $true)]
        [ValidateSet("No Auditing","Success","Failure","Success and Failure")]
        [System.String]
        $AuditLevel
    )
    $ErrorActionPreference = 'Stop'
    #Write-Verbose "Use this cmdlet to deliver information about command processing."
    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."
    $categoryParts = $Category.split(";")
    $majorcategory = $categoryParts[0]
    $minorcategory = $categoryParts[1]

    $new_policy_value = GetConfigValue $AuditLevel

    $ps = new-object System.Diagnostics.Process
    $ps.StartInfo.Filename = "auditpol.exe"
    $ps.StartInfo.Arguments = " /set /subcategory:`"$minorcategory`" $new_policy_value"
    $ps.StartInfo.RedirectStandardOutput = $True
    $ps.StartInfo.UseShellExecute = $false
    $ps.start()
    $ps.WaitForExit('10')
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet("System;IPsec Driver","System;System Integrity","System;Security System Extension","System;Security State Change","System;Other System Events","Logon/Logoff;Network Policy Server","Logon/Logoff;Other Logon/Logoff Events","Logon/Logoff;Special Logon","Logon/Logoff;IPsec Extended Mode","Logon/Logoff;IPsec Quick Mode","Logon/Logoff;IPsec Main Mode","Logon/Logoff;Account Lockout","Logon/Logoff;Logoff","Logon/Logoff;Logon","Logon/Logoff;User / Device Claims","Object Access;SAM","Object Access;Kernel Object","Object Access;Registry","Object Access;Application Generated","Object Access;Handle Manipulation","Object Access;File Share","Object Access;Filtering Platform Packet Drop","Object Access;Filtering Platform Connection","Object Access;Other Object Access Events","Object Access;Detailed File Share","Object Access;Removable Storage","Object Access;Central Policy Staging","Object Access;Certification Services","Object Access;File System","Privilege Use;Other Privilege Use Events","Privilege Use;Non Sensitive Privilege Use","Privilege Use;Sensitive Privilege Use","Detailed Tracking;RPC Events","Detailed Tracking;DPAPI Activity","Detailed Tracking;Process Termination","Detailed Tracking;Process Creation","Policy Change;Audit Policy Change","Policy Change;MPSSVC Rule-Level Policy Change","Policy Change;Filtering Platform Policy Change","Policy Change;Authorization Policy Change","Policy Change;Authentication Policy Change","Policy Change;Other Policy Change Events","Account Management;Security Group Management","Account Management;Distribution Group Management","Account Management;Other Account Management Events","Account Management;Application Group Management","Account Management;Computer Account Management","Account Management;User Account Management","DS Access;Directory Service Changes","DS Access;Directory Service Replication","DS Access;Directory Service Access","DS Access;Detailed Directory Service Replication","Account Logon;Other Account Logon Events","Account Logon;Kerberos Service Ticket Operations","Account Logon;Credential Validation","Account Logon;Kerberos Authentication Service")]
        [System.String]
        $Category,

        [parameter(Mandatory = $true)]
        [ValidateSet("No Auditing","Success","Failure","Success and Failure")]
        [System.String]
        $AuditLevel
    )
    $ErrorActionPreference = 'Stop'
    #Write-Verbose "Use this cmdlet to deliver information about command processing."
    #Write-Debug "Use this cmdlet to write debug information while troubleshooting."
    
    $CurrentSetting = Get-TargetResource -Category $Category -AuditLevel $AuditLevel

    # Need to test if case sensitivity matters here
    If ($AuditLevel -eq $CurrentSetting.AuditLevel)
    {
        return $true
    } else {
        return $false
    }
}

Export-ModuleMember -Function *-TargetResource
