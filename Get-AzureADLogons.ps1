Function Get-AzureADLogons{
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$False)][String]$LogName = "AzureADLogonInfoLog.csv",
	[Parameter(Mandatory=$False)][String]$LogPath = "C:\Temp",
	[Parameter(Mandatory=$False)][ValidateSet(1,2,3)]$DebugLevel = 3
  )
  Process{
    # Create log file if a file does not exist
    New-LogFile -LogName $LogName -LogPath $LogPath
	# Title
	Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType Header -Operation "Retrieve Azure Logon Information" -Details "Fetching Azure Logon Information"
	# Import template settings
	$Settings = Invoke-DistrictTemplate -Action ALL
    $resource = $Settings.resource
	$ReqTokenBody = $Settings.ReqTokenBody
	$URI = $Settings.Uri
	$RestTokenUri = $Settings.RestMethodUri
	Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "MSGraph Connection" -Details "Sending HTTP/S request to Representational State Transfer (REST) - $RestTokenUri"
	#The Invoke-RestMethod cmdlet sends HTTP and HTTPS requests to Representational State Transfer (REST) web services that return richly structured data.
    $TokenResponse = Invoke-RestMethod -Uri $RestTokenUri -Method POST -Body $ReqTokenBody
    # If the result is more than 999, we need to read the @odata.nextLink to show more than one side of users
    $Data = while (-not [string]::IsNullOrEmpty($URI)) {
    # API Call
      $apiCall = Try{
        Invoke-RestMethod -Headers @{Authorization = "Bearer $($Tokenresponse.access_token)"} -Uri $URI -Method Get
      }
      Catch{
        $errorMessage = $_.ErrorDetails.Message | ConvertFrom-Json
      }
      $URI = $null
      If($apiCall){
        # Check if any data is left
        $URI = $apiCall.'@odata.nextLink'
        $apiCall
      }
    }
	# Export results to variable
	$Result = ($Data | select-object Value).Value
	If(!($Result)){
	  Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType ERROR -Operation "Retrieve Azure Logon Information" -Details "Unable to retrieve Azure logon information"
	}Else{
	  Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType SUCCESS -Operation "Retrieve Azure Logon Information" -Details "Azure logon information retrieved successfully - Results $($Result.Count)"
      # Filter results
	  $Export = $Result | select DisplayName,UserPrincipalName,@{n="LastLoginDate";e={$_.signInActivity.lastSignInDateTime}}
	  # Set date time string to date time object
      [datetime]::Parse('2020-04-07T16:55:35Z')
	  # Export results
      #$Export | select DisplayName,UserPrincipalName,@{Name='LastLoginDate';Expression={[datetime]::Parse($_.LastLoginDate)}} | Export-CSV -Path C:\temp\AzureADLogons.csv
      # Capture filtered results in variable
	  $AzureADLogons = @()
	  ForEach($Entry in $Export){
	  If($Entry.LastLoginDate){
	    $AzureLastLogonDate = Get-Date $Entry.Lastlogindate.Replace("-","/")
	  }Else{
	    $AzureLastLogonDate = "N/A"
	  }
	  $AzureADLogons += New-Object -TypeName PSObject -Property @{DisplayName = $Entry.DisplayName;
																  UserPrincipalName = $Entry.UserPrincipalName;
																  AzureLastLogonDate = $AzureLastLogonDate;}
	  }														  
	  # Return filtered results
	  Return $AzureADLogons
	}
  }
}
