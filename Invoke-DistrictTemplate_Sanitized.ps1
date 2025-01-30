Function Invoke-DistrictTemplate{
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$True)][ValidateSet("ALL","AVDC","BCC","CSB","WDC")]$Action
  )
  Process{
    Switch($Action){
	  "ALL"{
	    $Primary = @(<#Insert Primary DC names#>);
		$LicenseGroups = @(<#Insert Azure AD License Group names#>);
		$Servers = @(<#Insert names of all district servers#>)
	  }
	  "AVDC"{
	    $Primary = #Insert Primary DC name
		$LicenseGroups = #Insert Azure AD License Group names
		$Servers = @(<#Insert names of all AVDC servers#>)
	  }
	  "BCC"{
	    $Primary = #Insert Primary DC name
		$LicenseGroups = #Insert Azure AD License Group names
		$Servers = @(<#Insert names of all BCC servers#>)
	  }
	  "CSB"{
	    $Primary = #Insert Primary DC name
		$LicenseGroups = #Insert Azure AD License Group names
		$Servers = @(<#Insert names of all CSB servers#>)
	  }
	  "WDC"{
	    $Primary = #Insert Primary DC name
		$LicenseGroups = #Insert Azure AD License Group names
		$Servers = @(<#Insert names of all WDC servers#>)
	  }
	}
    New-Object -TypeName PSObject -Property @{MasterDC = #DC1
	                                          MasterDCOutputPath = "C:\Temp\ADOutput"
											  ExportRetentionThreshold = 30
											  StaleUserThreshold = 60
											  Username = #serveradmin
											  EncryptedPassword = #EncryptedPasswordHere
											  AESKey = (Import-AESKey -KeyType ADMaintenance)
											  AzEncryptedPassword = #EncryptedPasswordHere
											  AzAESKey = (Import-AESKey -KeyType Azure);
											  AzUsername = #Azure admin
											  EmailRecipient = # Report recipient email
											  EmailSender = # Report sender email
											  Primary = $Primary;
											  LicenseGroups = $LicenseGroups;
											  Servers = $Servers;
											  LogPath = $LogPath;
											  DebugLevel = $DebugLevel;
		                                      TenantName = #TenantName
		                                      Resource = "https://graph.microsoft.com/";
		                                      ReqTokenBody = @{Grant_Type = "client_credentials";
                                                               Scope = "https://graph.microsoft.com/.default";
                                                               Client_Id = #Client ID;
                                                               Client_Secret = #Secret Value Here
															   }
											  RestMethodUri = "https://login.microsoftonline.com/buckscc.onmicrosoft.com/oauth2/v2.0/token"
		                                      Uri = 'https://graph.microsoft.com/beta/users?$select=displayName,userPrincipalName,signInActivity'
											  ExcludedOUs = @(#'CN=Microsoft Exchange System Objects',
															  <#Other various ADOU strings to be excluded#>)}
  }
}
