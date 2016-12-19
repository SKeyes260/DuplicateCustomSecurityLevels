

Function Duplicate-UpdateInfoCustomSeverity {
param(   $TargetSiteServer,   
         $TargetSiteCode,
         $ReferenceSiteServer,   
         $ReferenceSiteCode,
         $UpdateCIIDs,
         [switch]$verbose )

    $UpdateDetails = @()

    if ($verbose) { WRITE-HOST CS  `t CIID  `t Bulletin  `t Article `t Title }
    ForEach ($CIID in $UpdateCIIDs) {
        $objTargetUpdate = Get-WmiObject -ComputerName $TargetSiteServer -Namespace ("root\sms\Site_"+$TargetSiteCode) -Query "SELECT * FROM SMS_SoftwareUpdate WHERE CI_ID = '$CIID'"  
        $objReferenceUpdate = Get-WmiObject -ComputerName $ReferenceSiteServer -Namespace ("root\sms\Site_"+$ReferenceSiteCode) -Query ("SELECT * FROM SMS_SoftwareUpdate WHERE ArticleID = '"+$objTargetUpdate.ArticleID+"' AND BulletinID='"+$objTargetUpdate.BulletinID+"' AND LocalizedDisplayName = '"+$objTargetUpdate.LocalizedDisplayName+"'")  
        $objTargetUpdate['CustomSeverity'] = $objReferenceUpdate['CustomSeverity']
        $objTargetUpdate.Put()
        if ($verbose) { WRITE-HOST $objReferenceUpdate.CustomSeverity  `t $CIID `t $objReferenceUpdate.BulletinID  `t $objReferenceUpdate.ArticleID  `t $objReferenceUpdate.LocalizedDisplayName  }
        $UpdateDetails += "$objReferenceUpdate['CustomSeverity'] `t $CIID  `t $objReferenceUpdate['BulletinID'] `t $objReferenceUpdate['ArticleID'] `t $objReferenceUpdate['LocalizedDisplayName']"

    }
    Return $UpdateDetails
}


Function Get-CIIDs_From_UpdateList {
param(   $SiteServer,   
         $SiteCode,
         $UpdateListName )

       $objAuthList = Get-WmiObject -ComputerName $SiteServer -Namespace ("root\sms\Site_"+$SiteCode) -Class "SMS_AuthorizationList" -Filter ("LocalizedDisplayName = '"+$UpdateListName+"'")
    $objAuthList = [wmi]$objAuthList.__PATH
    #$objAuthList.Updates | %{  WRITE-HOST  $_   }
    Return @($objAuthList.Updates )
}


Function Get-UpdateInfo {
param(   $SiteServer,   
         $SiteCode,
         $Update_CIID,
         [switch]$verbose )

       $objUpdate = Get-WmiObject -ComputerName $SiteServer -Namespace ("root\sms\Site_"+$SiteCode) -Class "SMS_SoftwareUpdate" -Filter ("CI_ID = "+$Update_CIID)
    if (!$objUpdate) { WRITE-HOST ("Could not find an update with a CI_ID of "+$Update_CIID) ; EXIT }
    $objUpdate = [wmi]$objUpdate.__PATH
    if ($verbose) { WRITE-HOST ($objUpdate.BulletinID+", "+$objUpdate.ArticleID+", "+$objUpdate.LocalizedDisplayName ) 
     WRITE-HOST (", "+$objUpdate.UpdateLocales )}
    Return $objUpdate
}



Function CheckForUpdateList {
    [CmdletBinding()] 
    PARAM  (  
        [Parameter(Position=1)] $SiteServer,
        [Parameter(Position=2)] $SiteCode,
        [Parameter(Position=3)] $UpdateListName
    ) 

# Check if the specified name for the source update list exists
$UpdateList = Get-WMIObject -ComputerName $SiteServer -NameSpace "Root\SMS\Site_$SiteCode" -Query ("SELECT * FROM SMS_AuthorizationList WHERE LocalizedDisplayName = '"+$UpdateListName+"'")
$ListID = $UpdateList.CI_ID
Return $ListID
}



#########################
#         MAIN
#########################

#Global Variables
$SelectedList = @()
$AllUpdateLists =@()
$UpdateCIIDs = @()

$ReferenceSiteCode = "EC0"
$ReferenceSiteServer = "RESSWCMSPRIP01"
$TargetSiteCode = "P00"
$TargetSiteServer = "XSPW10W200P"
#$TargetSiteCode = "F01"
#$TargetSiteServer = "XSNW10S629K"
$Verbose = $True

$AllUpdateLists = Get-WMIObject -ComputerName $TargetSiteServer -NameSpace "Root\SMS\Site_$TargetSiteCode" -Query "SELECT LocalizedDisplayName FROM SMS_AuthorizationList"
$Result = $AllUpdateLists | Select-Object -Property "LocalizedDisplayName" | Sort-Object "LocalizedDisplayName" |  Out-GridView  -PassThru  -OutVariable "SelectedList"  -Title "Select an update list tio assign custom severity levels for and click OK"  
$UpdateListNames = $SelectedList.LocalizedDisplayName

Foreach ( $UpdateListName in $UpdateListnames ) {
    If (!$UpdateListName) {  WRITE-HOST ("Update List Name cannot be empty, exiting") ;   Exit }
    WRITE-HOST "There may be a short period of time with no screen activity depending on the number of entries in the update list"

    $UpdateListID = CheckForUpdateList -SiteServer $TargetSiteServer -SiteCode $TargetSiteCode -UpdateListName $UpdateListName  
    If (!$UpdateListID) { WRITE-HOST ("Update list named '"+$UpdateListName+"' was not found, exiting") ; EXIT }

    $UpdateCIIDs = Get-CIIDs_From_UpdateList -SiteServer $TargetSiteServer -SiteCode $TargetSiteCode -UpdateListName $UpdateListName

    # Display the updates in the target UL
    cls
    $UpdateDetails = Duplicate-UpdateInfoCustomSeverity -TargetSiteServer $TargetSiteServer -TargetSiteCode $TargetSiteCode  -ReferenceSiteServer $ReferenceSiteServer  -ReferenceSiteCode $ReferenceSiteCode -UpdateCIIDs $UpdateCIIDs -verbose $verbose
    
    ADD-Content "C:\test\DuplicateCustomSecurity.txt"  $UpdateDetails
}





