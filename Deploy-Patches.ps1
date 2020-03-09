<#
 # Script:          Auto Deploy Patches for SCCM (SL2 Site)
 # Author:          Jose Magallanes
 # Created:         11/02/2019
 # Updates:         03/03/2020
#>

# user is returned at the end of the script run
$startlocation = Get-Location

#Import functions
. $startlocation\Get-PatchTuesday.ps1
. $startlocation\Set-UpdateGroupName.ps1

# Site configuration
$SiteCode = "SL2" # Site code 
$ProviderMachineName = "smsaus003.silabs.com" # SMS Provider name

# Customizations
$initParams = @{}
#$initParams.Add("Verbose", $true) # enable verbose logging
#$initParams.Add("ErrorAction", "Stop") # stop the script on any errors

#### DO NOT CHANGE ANYTHING BELOW THIS LINE
# Import the ConfigurationManager.psd1 module 
if($null -eq (Get-Module ConfigurationManager)) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" `
                  @initParams 
}
# Connect to the site's drive if it is not already present
if($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite `
              -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite `
                -Root $ProviderMachineName @initParams
}
# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams
### DO NOT CHANGE ANYTHING ABOVE THIS LINE

# Maintenance Window Constants
$MW_DEV_COLLECTION = 'SL20007A'
$MW_SAP_DEV_COLLECTION = 'SL20008A'
$MW_QA_COLLECTION = 'SL20007C'
$MW_SCCM_COLLECTION = 'SL20008C'
$MW_EGL_COLLECTION = 'SL200081' 
$MW_SAP_PROD_COLLECTION = 'SL200080'
$MW_AD_ITS_COLLECTION = 'SL20008E'
$MW_Z_FULL_PATCH_COLLECTION = 'SL20007F'

# Deployment Constants
$DEV_SERVERS = 'SL20004A'
$QA_SERVERS = 'SL200049'
$SAP_DEV_SERVERS = 'SL20008B'
#$SUM_SCCM_SERVERS = 'SL200076'
#$EGL_SERVERS_COLLECTION = 'SL200078'
#$SUM_ADITS_SERVERS = 'SL20008F'
#$SAP_PRODUCTION_COLLECTION = 'SL20004B'
#$Z_FULL_PATCH_COLLECTION = 'SL20004F'

# Import Get-PatchTuesday function and calculate
$patch_tuesday = Get-PatchTuesday
$patch_tuesday = $patch_tuesday.ToUniversalTime() #This is Austin 12 AM -> UTC

<# Patch Timing Calculations#>
# Dev Maintenance Window Time (Thursday of Patch Tuesday Week)
$dev_start_time = $patch_tuesday.AddDays(2).AddHours(5).AddMinutes(45)
$dev_end_time = $dev_start_time.AddHours(4)

# QA Maintenance Window Time (Friday of Patch Tuesday Week)
$qa_start_time = $dev_start_time.AddDays(1)
$qa_end_time = $qa_start_time.AddHours(4)

# SCCM Maintenance Window Time (Saturday of Patch Tuesday Week)
$sccm_start_time = $dev_start_time.AddDays(2)
$sccm_end_time = $sccm_start_time.AddHours(4)

# Production Maintenance Window Time (Next Sat. after Patch Tues.)
$prod_start_time = $patch_tuesday.AddDays(11).AddHours(8)
$prod_end_time = $prod_start_time.AddHours(4)

<# Confirm Patch Timing#>
Clear-Host
Write-Host "Patch Schedule to be Pushed (UTC Time)"
Write-Host "-----------------------------------------------"
Write-Host "Dev and SAP Dev Patching:", $dev_start_time
Write-Host "QA Patching:             ", $qa_start_time
Write-Host "SCCM Patching:           ", $sccm_start_time
Write-Host "Production Servers:      ", $prod_start_time

$con_title    = 'Patch Timing Check'
$con_question = 'Is this correct?'
$con_choices  = '&Yes', '&No'
$continue = $Host.UI.PromptForChoice($con_title, $con_question, $con_choices, 1)
if ($continue -eq 0) {
    Write-Host "`n`nChecking for this month's Software Update Group..."
}
else {
    Write-Host "`n`nYou'll have to do this manually. Exiting."
    Set-Location $startlocation
    Exit
}

###### Create Month Header, for deployment naming
$suName = Set-UpdateGroupName -day $patch_tuesday
$last_sug = Get-CMSoftwareUpdateGroup | Sort-Object DateCreated `
                       | Select-Object * -Last 1 #Last created SUG
Write-Host "Last Software Group",($last_sug.DateCreated.Month)
Write-Host "This month",($patch_tuesday.Month)

# Check if this month's patch SUG has been created, rename if necessary
if ($last_sug.DateCreated.Month -ne $patch_tuesday.Month) {
    Write-Host "This month's Software Update Group has not been created" `
               "yet. Please try again after Patch Tuesday."
    Exit
} else {
    if ($last_sug.LocalizedDisplayName -ne $suName) {
        Write-Host "Renaming auto-created Software Update Group..."
        Set-CMSoftwareUpdateGroup -Name $last_sug.LocalizedDisplayName `
                                  -NewName $suName
    }
}
$cur_sug = $last_sug.LocalizedDisplayName

<# Create Maintenance Windows #>
#Dev and SAP Dev (Dev, QA, and MiSC)
$dev_schedule = New-CMSchedule -End $dev_end_time -Start $dev_start_time `
                               -Nonrecurring -IsUTC
New-CMMaintenanceWindow -CollectionId $MW_DEV_COLLECTION `
                        -Name ($suName + ' - MW Dev Servers')  `
                        -Schedule $dev_schedule -ApplyTo SoftwareUpdatesOnly
New-CMMaintenanceWindow -CollectionId $MW_SAP_DEV_COLLECTION `
                        -Name ($suName + ' - MW SAP Dev,QA,Misc Servers') `
                        -Schedule $dev_schedule -ApplyTo SoftwareUpdatesOnly

#QA Collection
$qa_schedule = New-CMSchedule -End $qa_end_time -Start $qa_start_time `
                              -Nonrecurring -IsUTC
New-CMMaintenanceWindow -CollectionId $MW_QA_COLLECTION `
                        -Name ($suName + ' - MW QA Servers') `
                        -Schedule $qa_schedule -ApplyTo SoftwareUpdatesOnly

#SCCM Collection
$sccm_schedule = New-CMSchedule -End $sccm_end_time -Start $sccm_start_time `
                                -Nonrecurring -IsUTC
New-CMMaintenanceWindow -CollectionId $MW_SCCM_COLLECTION `
                        -Name ($suName + ' - MW SUM SCCM') `
                        -Schedule $sccm_schedule -ApplyTo SoftwareUpdatesOnly

#Production Collections
$prod_schedule = New-CMSchedule -End $prod_end_time -Start $prod_start_time
                                -Nonrecurring -IsUTC
New-CMMaintenanceWindow -CollectionId $MW_AD_ITS_COLLECTION `
                        -Name ($suName + ' - MW AD/ITS Servers') `
                        -Schedule $prod_schedule -ApplyTo SoftwareUpdatesOnly
New-CMMaintenanceWindow -CollectionId $MW_SAP_PROD_COLLECTION `
                        -Name ($suName + ' - MW SAP PROD Servers') `
                        -Schedule $prod_schedule -ApplyTo SoftwareUpdatesOnly
New-CMMaintenanceWindow -CollectionId $MW_EGL_COLLECTION `
                        -Name ($suName + ' - MW EGL Servers') `
                        -Schedule $prod_schedule -ApplyTo SoftwareUpdatesOnly
New-CMMaintenanceWindow -CollectionId $MW_Z_FULL_PATCH_COLLECTION `
                        -Name ($suName + ' - MW Z-Full Patch Servers') `
                        -Schedule $prod_schedule -ApplyTo SoftwareUpdatesOnly


#$desc = 'Patch Tuesday'
# SUM DEV SERVERS DEPLOYMENT
New-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $cur_sug `
                               -DeploymentNam ($suName + ' - SUM DEV Servers') `
                               -Description 'Patch Tuesday' `
                               -DeploymentType Required `
                               -TimeBasedOn UTC `
                               -UserNotification DisplaySoftwareCenterOnly `
                               -DeadlineDateTime $dev_start_time `
                               -CollectionId $DEV_Servers `
                               -RequirePostRebootFullScan $true `
                               -DownloadFromMicrosoftUpdate $true

# SUM SAP DEV,QA,MISC SERVERS DEPLOYMENT
New-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $cur_sug `
                               -DeploymentN ($suName + 
                                             ' - SUM SAP DEV,QA,MISC Servers') `
                               -Description 'Patch Tuesday' `
                               -DeploymentType Required `
                               -TimeBasedOn UTC `
                               -UserNotification DisplaySoftwareCenterOnly `
                               -DeadlineDateTime $dev_start_time `
                               -CollectionID $SAP_DEV_SERVERS `
                               -RequirePostRebootFullScan $true `
                               -DownloadFromMicrosoftUpdate $true

# SUM QA SERVERS DEPLOYMENT
New-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $cur_sug `
                               -DeploymentName ($suName + ' - SUM QA Servers') `
                               -Description 'Patch Tuesday' `
                               -DeploymentType Required `
                               -TimeBasedOn UTC `
                               -UserNotification DisplaySoftwareCenterOnly `
                               -AvailableDateTime $dev_start_time `
                               -DeadlineDateTime $qa_start_time `
                               -CollectionId $QA_SERVERS `
                               -RequirePostRebootFullScan $true `
                               -DownloadFromMicrosoftUpdate $true

# SUM SCCM SERVERS DEPLOYMENT
New-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $cur_sug `
                               -DeploymentName ($suName + 
                                                ' - SUM SCCM Servers') `
                               -Description 'Patch Tuesday' `
                               -DeploymentType Required `
                               -TimeBasedOn UTC `
                               -UserNotification DisplaySoftwareCenterOnly `
                               -AvailableDateTime $sccm_start_time `
                               -DeadlineDateTime $sccm_end_time `
                               -CollectionID $SUM_SCCM_SERVERS `
                               -RequirePostRebootFullScan $true `
                               -DownloadFromMicrosoftUpdate $true

<# UNCOMMENT NEXT PATCH CYCLE
New-CMSoftwareUpdateDeployment -InputObject $sup -DeploymentName ($suName + 'SCCM Test Servers') `
    -Description $desc -DeploymentType Required -TimeBasedOn UTC -UserNotification DisplaySoftwareCenterOnly `
    -RequirePostRebootFullScan $true -DownloadFromMicrosoftUpdate $true -DeadlineDateTime $prod_start_time `
    -CollectionID 'SL200076' -UseBranchCache $true -ProtectedType RemoteDistributionPoint
#>

#DEV Deployment
#New-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $cur_sug -DeploymentName ($suName + 'DEV Servers') `
#    -Description 'Patch Tuesday' -DeploymentType Required -TimeBasedOn UTC -UserNotification DisplaySoftwareCenterOnly `
#    -DeadlineDateTime $dev_start_time -CollectionId 'SL20004A'


#SAP DEV,QA,MISC Deployment (Same start time as DEV)
#New-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $cur_sug -DeploymentName ($suName + 'SAP DEV,QA,MISC Servers') `
#    -Description 'Patch Tuesday' -DeploymentType Required -TimeBasedOn UTC -UserNotification DisplaySoftwareCenterOnly `
#    -DeadlineDateTime $dev_start_time -CollectionId 'SL20008B'



    
<#SCCM Deployment
New-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $cur_sug -DeploymentName ($suName + 'SUM SCCM Servers') `
    -Description 'Patch Tuesday' -DeploymentType Required -TimeBasedOn UTC -UserNotification DisplaySoftwareCenterOnly `
    -DeadlineDateTime $sccm_start_time -CollectionId 'SL200076' -RequirePostRebootFullSca $true -DownloadFromMicrosoftUpdate $true
#>
#Re-evaluate; Neighbor boundary group; download from MS



# EGL SUM Deployment
#New-CMSoftwareUpdateDeployment -InputObject $sup -DeploymentName ($suName + 'EGL Servers') `
#    -DeploymentType Required -TimeBasedOn UTC -UserNotification DisplaySoftwareCenterOnly `
#    -RequirePostRebootFullScan $true -DownloadFromMicrosoftUpdate $true -DeadlineDateTime $egl_start_time `
#    -CollectionID $EGL_SERVERS_COLLECTION -UseBranchCache $true -ProtectedType RemoteDistributionPoint

#New-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $sup -DeploymentName ($suName + ' - SCCM Test Servers') `
#    -Description 'Patch Tuesday' -DeploymentType Required -TimeBasedOn UTC -UserNotification DisplaySoftwareCenterOnly `
#    -DeadlineDateTime $sccm_start_time -CollectionId 'SL200076' -whatif


Set-Location $startlocation # Puts us back in the original file location


#>