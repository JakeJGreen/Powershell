# Current max runtime: 1 Milliseconds
Function Invoke-NTFSTemplate{
  <#
  .SYNOPSIS
    Templated Settings for NTFS

  .DESCRIPTION
    Settings for assigning permissions on files and folders
    	
  .OUTPUTS
    PSObject providing a list of NTFS settings
    
  .NOTES
    Version:        1.0
    Author:         Jake Green
    Creation Date:  15/09/2021
    Purpose/Change: Initial function development and debug mode support
	
  .EXAMPLE
    $Settings = Invoke-NTFSTemplate
	$Settings.Owner
	BUILTIN\Administrators
    
#> 
  $DateTime = Get-Date -format ddMMyyyy_hhmm
  $Settings = New-Object -TypeName PSObject -Property @{Owner = "Administrators"
														OwnerDomain = "BUILTIN"
                                                        TargetUserDomain = "$Env:USERDOMAIN";
													    LogPath = "C:\Temp\Logs";
													    LogName = $DateTime + "_" + "FolderPermissions_Log.csv";
														BackupFile = "NTFS Legacy Permissions Backups.csv";
														DebugLevel = 3;
														FileSystemRights = "FullControl";
														ExcludedUsers = @("NT AUTHORITY\SYSTEM",
																		  "BUILTIN\Administrators",
																		  "BUILTIN\Users",
																		  "NT AUTHORITY\Authenticated Users")}
  Return $Settings
}
