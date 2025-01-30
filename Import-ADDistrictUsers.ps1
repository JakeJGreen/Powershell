Function Import-ADDistrictUsers{
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$True)][ValidateSet("ALL","AVDC","BCC","CSB","WDC")]$Action,
    [Parameter(Mandatory=$False)][String]$ImportPath = (Invoke-DistrictTemplate -Action ALL).MasterDCOutputPath,
	[Parameter(Mandatory=$False)][String]$FileName,
	[Parameter(Mandatory=$False)][String]$LogName = "ADDistrictUserImportLog.csv",
	[Parameter(Mandatory=$False)][String]$LogPath = "C:\Temp",
	[Parameter(Mandatory=$False)][ValidateSet(1,2,3)]$DebugLevel = 3
  )
  Process{
	# Create log file if a file does not exist
    New-LogFile -LogName $LogName -LogPath $LogPath
	# Title
	Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType Header -Operation "Import District AD Users" -Details "Import $($Action) AD User list"
	# Import template settings
	$Settings = Invoke-DistrictTemplate -Action $Action
	# ===== VALIDATE IMPORT PATH =====
	If($ImportPath -ne $($Settings.MasterDCOutputPath)){
	  # If custom import path, test path
	  $TestPath = Test-Path $ImportPath
	  If($TestPath){
	    # If path found write log
	    Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType SUCCESS -Operation "Custom AD User Import Path" -Details "Path is valid and accessible $ImportPath"
	  }Else{
	    # If path found write log
		Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType ERROR -Operation "Custom AD User Import Path" -Details "Import path could not be found $ImportPath"
	  }
	}Else{
	  $ImportPath = "\\$($Settings.MasterDC)\$($ImportPath.Replace(":","$"))"
	  # if the import path is set to the default export path on DC001 re-format the path for remote location i.e. \\DC001\C$...
      $TestPath = Test-Path $ImportPath
	  If($TestPath){
	    # If path found write log
	    Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType SUCCESS -Operation "Default AD User Path" -Details "Path is valid and accessible"
	  }Else{
	    # If path found write log
		Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType ERROR -Operation "Default AD User Path" -Details "Import path is invalid or could not be found $ImportPath"
	  }
	}
	# ================================
	# ===== IMPORT AD USER EXPORT =====
	If($FileName){
	  # join path and file name to creat file full name
	  $FileFullName = $ImportPath + "\" + $FileName
	  Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType NOTE -Operation "Custom AD User File" -Details "Full file path is $FileFullName"
	  # test file full name
	  $TestPath = Test-Path $FileFullName
	  If($FileFullName){
	    # If path found write log
	    Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType SUCCESS -Operation "Default AD User File" -Details "Full file path is valid and accessible"
		$ADUsers = Import-Csv $FileFullName
	  }Else{
	    # If path found write log
		Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType ERROR -Operation "Default AD User File" -Details "Full file path is invalid or could not be found $FileFullName"
	  }
	}Else{
	  # fetch all files in import location
	  $ExportDate = Get-Date -Format ddMMyyyy
	  If($Action -eq "ALL"){
	    # Import all domains file with todays date
	    $ADUsers = Import-Csv "$ImportPath\AllUsers-AllDomains-$ExportDate.csv"
	    If(!($ADUsers)){
	      # cannot import file
		  Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType ERROR -Operation "Import Default AD User File" -Details "AD user file could not be imported"
	      # cannot find the following file: $ImportPath\AllUsers-AllDomains-$ExportDate.csv
		  If(!(Test-Path "$ImportPath\AllUsers-AllDomains-$ExportDate.csv")){
		    Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType ERROR -Operation "Import Default AD User File" -Details "Unable to locate import file $ImportPath\AllUsers-AllDomains-$ExportDate.csv"
		  }
	    }Else{
	      # import successful users count
		  Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType SUCCESS -Operation "Import Default AD User File" -Details "AD user file imported successfully - Users $($ADUsers.Count)"
	    }
	    # If specific domain has been set
	  }Else{
	    # Import file for select domain with todays date
	    $ADUsers = Import-Csv "$ImportPath\AllUsers-$($Action)Domain-$ExportDate.csv"
	    If(!($ADUsers)){
	      # cannot import file
		  Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType ERROR -Operation "Import Default AD User File" -Details "AD user file could not be imported"
	      # cannot find the following file: $ImportPath\AllUsers-AllDomains-$ExportDate.csv
		  If(!(Test-Path "$ImportPath\AllUsers-AllDomains-$ExportDate.csv")){
	        # cannot find the following file: $ImportPath\AllUsers-$($Action)Domain-$ExportDate.csv
		    Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType ERROR -Operation "Import Default AD User File" -Details "Unable to locate import file $ImportPath\AllUsers-AllDomains-$ExportDate.csv"
		  }
	    }Else{
	      # import successful users count
		  Write-LogFile -DebugLevel $DebugLevel -LogPath $LogPath -LogName $LogName -EntryType SUCCESS -Operation "Import Default AD User File" -Details "AD user file imported successfully - $($Action) Users $($ADUsers.Count)"
	    }
	  }
	}
	Return $ADUsers
	# =================================
  }
}
