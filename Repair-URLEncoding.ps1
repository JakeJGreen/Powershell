function Import-UrlEncodingCharMap {    
    begin {
        $EncodingCharacterMap = @()
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "Dollar";
            CharacterSymbol                                                              = '$';
            HexCode                                                                      = '%24'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "Ampersand";
            CharacterSymbol                                                              = '&';
            HexCode                                                                      = '%26'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "Plus";
            CharacterSymbol                                                              = '+';
            HexCode                                                                      = '%2B'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "Comma";
            CharacterSymbol                                                              = ',';
            HexCode                                                                      = '%2C'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "ForwardSlash";
            CharacterSymbol                                                              = '/';
            HexCode                                                                      = '%2F'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "Colon";
            CharacterSymbol                                                              = ':';
            HexCode                                                                      = '%3A'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "SemiColon";
            CharacterSymbol                                                              = ';';
            HexCode                                                                      = '%3B'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "Equals";
            CharacterSymbol                                                              = '=';
            HexCode                                                                      = '%2D'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "QuestionMark";
            CharacterSymbol                                                              = '?';
            HexCode                                                                      = '%3F'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "AtSymbol";
            CharacterSymbol                                                              = '@';
            HexCode                                                                      = '%40'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "Space";
            CharacterSymbol                                                              = ' ';
            HexCode                                                                      = '%20'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "QuotationMarks";
            CharacterSymbol                                                              = '"';
            HexCode                                                                      = '%22'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "LessThan";
            CharacterSymbol                                                              = '<';
            HexCode                                                                      = '%3C'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "GreaterThan";
            CharacterSymbol                                                              = '>';
            HexCode                                                                      = '%3E'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "Pound";
            CharacterSymbol                                                              = '#';
            HexCode                                                                      = '%23'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "Percentage";
            CharacterSymbol                                                              = '%';
            HexCode                                                                      = '%25'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "LeftCurlyBrace";
            CharacterSymbol                                                              = '{';
            HexCode                                                                      = '%7B'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "RightCurlyBrace";
            CharacterSymbol                                                              = '}';
            HexCode                                                                      = '%7D'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "Pipe";
            CharacterSymbol                                                              = '|';
            HexCode                                                                      = '%7C'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "Backslash";
            CharacterSymbol                                                              = '\';
            HexCode                                                                      = '%5C'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "Caret";
            CharacterSymbol                                                              = '^';
            HexCode                                                                      = '%5E'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "Tilde";
            CharacterSymbol                                                              = '~';
            HexCode                                                                      = '%7E'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "LeftSquareBracket";
            CharacterSymbol                                                              = '[';
            HexCode                                                                      = '%5B'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "RightSquareBracket";
            CharacterSymbol                                                              = ']';
            HexCode                                                                      = '%5D'
        }
        $EncodingCharacterMap += New-Object -TypeName PSObject -Property @{CharacterName = "GraveAccent";
            CharacterSymbol                                                              = '`';
            HexCode                                                                      = '%60'
        }
    }
    
    process {
        
    }
    
    end {
        Return $EncodingCharacterMap
    }
}  
Function Repair-URLEncoding {
    <#
    .SYNOPSIS
        A short one-line action-based description, e.g. 'Tests if a function is valid'
    .DESCRIPTION
        A longer description of the function, its purpose, common use cases, etc.
    .NOTES
        Requires URL Encoding map, either Import-UrlEncodingCharMap, or .csv file I:\Tools\URLCharacterEncoding.csv
    .LINK
        Specify a URI to a help page, this will show when Get-Help -Online is used.
    .EXAMPLE
        Test-MyTestFunction -Verbose
        Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)][String]$String,
        [Parameter(Mandatory = $False)][PSObject]$EncodingMap = (Import-UrlEncodingCharMap),
        [Parameter(Mandatory = $True)][String]$OutputPath
    )
    # Import EncodingMap
    If ($EncodingMap -like $null) {
        Try {
            $EncodingMap = Import-Csv "C:\Users\jjgreen\OneDrive - Buckinghamshire Council\Documents\2. Area\Excel\URLCharacterEncoding.csv"
        }
        Catch { Write-Error "Unable to import EncodingMap - Check path $($EncodingMap)" }
    }
    $i = 0
    $Activity = "Replacing URL Encoding with Special Characters"
    $Count = $($EncodingMap).Count
    # Store original string
    $OldString = $String
    ForEach ($Entry in $EncodingMap) {
        $i ++
        $PercentComplete = ($i / $Count * 100)
        $Status = "$i of $Count | %Complete: $PercentComplete"
        $Task = "Active Character $($Entry.CharacterName) - $($Entry.CharacterSymbol)"
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -CurrentOperation $Task
        $String = $String.Replace("$($Entry.HexCode)", "$($Entry.CharacterSymbol)")
    }
    # Store changes made as new string
    $NewString = $String
    $Results = New-Object -TypeName PSObject -Property @{OldString = $OldString;
        NewString                                                  = $NewString
    }
    If ($Results) {
        Write-Host "Repair completed." -F Green
        $Results | Export-Csv "$OutputPath\URLEncodingRepair.csv" -NoTypeInformation -Force
        Return $Results
    }
    Else {
        Write-Host "Repair could not complete. $(($Error | Select -First 1).Exception.Message)" -F RED
    }
}
