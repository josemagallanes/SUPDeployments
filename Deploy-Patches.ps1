<#
 # Script:          Auto Deploy Patches for SCCM (SL2 Site)
 # Author:          Jose Magallanes
 # Created:         11/02/2019
 # Updates:         03/03/2020
#>


# Get the initial location, so the user is returned at the end of the script run.
$startlocation = Get-Location

#Import functions
. $startlocation\Get-PatchTuesday.ps1
. $startlocation\Set-UpdateGroupName.ps1

# Site configuration
$SiteCode = "SL2" # Site code 
$ProviderMachineName = "smsaus003.silabs.com" # SMS Provider machine name

# Customizations
$initParams = @{}
#$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
#$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

#### DO NOT CHANGE ANYTHING BELOW THIS LINE
# Import the ConfigurationManager.psd1 module 
if($null -eq (Get-Module ConfigurationManager)) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}

# Connect to the site's drive if it is not already present
if($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
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
$SUM_SCCM_SERVERS = 'SL200076'
$EGL_SERVERS_COLLECTION = 'SL200078'
$SUM_ADITS_SERVERS = 'SL20008F'
$SAP_PRODUCTION_COLLECTION = 'SL20004B'
$Z_FULL_PATCH_COLLECTION = 'SL20004F'

# Import Get-PatchTuesday function and calculate
$patch_tuesday = Get-PatchTuesday
Write-Host 'Patch Tuesday:' $patch_tuesday
$patch_tuesday = $patch_tuesday.ToUniversalTime() #This is Austin 12 AM -> UTC
#Write-Host 'Patch Tuesday UTC time:'$patch_tuesday

### Patch Timing Calculations
# Dev Maintenance Window Time (Thursday of Patch Tuesday Week)
$dev_start_time = $patch_tuesday.AddDays(2).AddHours(5).AddMinutes(45)
$dev_end_time = $dev_start_time.AddHours(4)

# QA Maintenance Window Time (Friday of Patch Tuesday Week)
$qa_start_time = $dev_start_time.AddDays(1)
$qa_end_time = $qa_start_time.AddHours(4)

# SCCM Maintenance Window Time (Saturday of Patch Tuesday Week)
$sccm_start_time = $dev_start_time.AddDays(2)
$sccm_end_time = $sccm_start_time.AddHours(4)

#####DEPRECIATED######
# EGL Maintenance Window Time (Typically Friday before Maint. Window)
#$egl_start_time = $patch_tuesday.AddDays(10).AddHours(11)
#$egl_end_time = $egl_start_time.AddHours(4)

# Production Maintenance Window Time (Next Sat. after Patch Tues.)
$prod_start_time = $patch_tuesday.AddDays(11).AddHours(8)
$prod_end_time = $prod_start_time.AddHours(4)

###### Create Month Header, for deployment naming
$softwareUpdateName = Set-UpdateGroupName -day $patch_tuesday
Write-Host $softwareUpdateName #DELETEME


# Get Software Update Group
$sup = Get-CMSoftwareUpdateGroup -Name $softwareUpdateName

### Create Maintenance Windows ###
#$dev_schedule = New-CMSchedule -End $dev_end_time -Start $dev_start_time -Nonrecurring -IsUTC
#$qa_schedule = New-CMSchedule -End $qa_end_time -Start $qa_start_time -Nonrecurring -IsUTC
#$sccm_schedule = New-CMSchedule -End $sccm_end_time -Start $sccm_start_time -Nonrecurring -IsUTC
#$egl_schedule = New-CMSchedule -End $egl_end_time -Start $egl_start_time -Nonrecurring -IsUTC
#$prod_schedule = New-CMSchedule -End $prod_end_time -Start $prod_start_time -Nonrecurring -IsUTC


# Dev MW
#New-CMMaintenanceWindow -CollectionId $MW_DEV_COLLECTION -Name ($header + 'MW Dev Servers')  `
#    -Schedule $dev_schedule -ApplyTo SoftwareUpdatesOnly

# SAP DEV,QA,MISC MW
#New-CMMaintenanceWindow -CollectionId $MW_SAP_DEV_COLLECTION -Name ($header + 'MW SAP Dev,QA,Misc Servers') `
#    -Schedule $dev_schedule -ApplyTo SoftwareUpdatesOnly

# QA MW
#New-CMMaintenanceWindow -CollectionId $MW_QA_COLLECTION -Name ($header + 'MW QA Servers') `
#    -Schedule $qa_schedule -ApplyTo SoftwareUpdatesOnly

# SCCM MW
#New-CMMaintenanceWindow -CollectionId $MW_SCCM_COLLECTION -Name ($header + 'MW SUM SCCM') `
#    -Schedule $sccm_schedule -ApplyTo SoftwareUpdatesOnly

# EGL MW
#New-CMMaintenanceWindow -CollectionId $MW_EGL_COLLECTION -Name ($header + 'MW EGL Servers') `
#    -Schedule $egl_schedule -ApplyTo SoftwareUpdatesOnly

#SAP PROD MW
#New-CMMaintenanceWindow -CollectionId $MW_SAP_PROD_COLLECTION -Name ($header + 'MW SAP PROD Servers') `
#    -Schedule $prod_schedule -ApplyTo SoftwareUpdatesOnly

# AD/ITS MW
#New-CMMaintenanceWindow -CollectionId $MW_ADITS_COLLECTION -Name ($header + 'MW AD/ITS Servers') `
#    -Schedule $prod_schedule -ApplyTo SoftwareUpdatesOnly

# Z-Full Collection MW
#New-CMMaintenanceWindow -CollectionId $MW_Z_FULL_PATCH_COLLECTION -Name ($header + 'MW Z-Full Patch Servers') `
#    -Schedule $prod_schedule -ApplyTo SoftwareUpdatesOnly

#$desc = 'Patch Tuesday'

<# UNCOMMENT NEXT PATCH CYCLE
New-CMSoftwareUpdateDeployment -InputObject $sup -DeploymentName ($header + 'SCCM Test Servers') `
    -Description $desc -DeploymentType Required -TimeBasedOn UTC -UserNotification DisplaySoftwareCenterOnly `
    -RequirePostRebootFullScan $true -DownloadFromMicrosoftUpdate $true -DeadlineDateTime $prod_start_time `
    -CollectionID 'SL200076' -UseBranchCache $true -ProtectedType RemoteDistributionPoint
#>

#DEV Deployment
#New-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $sup.LocalizedDisplayName -DeploymentName ($header + 'DEV Servers') `
#    -Description 'Patch Tuesday' -DeploymentType Required -TimeBasedOn UTC -UserNotification DisplaySoftwareCenterOnly `
#    -DeadlineDateTime $dev_start_time -CollectionId 'SL20004A'


#SAP DEV,QA,MISC Deployment (Same start time as DEV)
#New-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $sup.LocalizedDisplayName -DeploymentName ($header + 'SAP DEV,QA,MISC Servers') `
#    -Description 'Patch Tuesday' -DeploymentType Required -TimeBasedOn UTC -UserNotification DisplaySoftwareCenterOnly `
#    -DeadlineDateTime $dev_start_time -CollectionId 'SL20008B'
<#
#QA Deployment
New-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $sup.LocalizedDisplayName -DeploymentName ($header + 'QA Servers') `
    -Description 'Patch Tuesday' -DeploymentType Required -TimeBasedOn UTC -UserNotification DisplaySoftwareCenterOnly `
    -DeadlineDateTime $qa_start_time -CollectionId 'SL200049' -RequirePostRebootFullScan $true -DownloadFromMicrosoftUpdate $true

#SCCM Deployment
New-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $sup.LocalizedDisplayName -DeploymentName ($header + 'SUM SCCM Servers') `
    -Description 'Patch Tuesday' -DeploymentType Required -TimeBasedOn UTC -UserNotification DisplaySoftwareCenterOnly `
    -DeadlineDateTime $sccm_start_time -CollectionId 'SL200076' -RequirePostRebootFullSca $true -DownloadFromMicrosoftUpdate $true

#>
#Re-evaluate; Neighbor boundary group; download from MS



# EGL SUM Deployment
#New-CMSoftwareUpdateDeployment -InputObject $sup -DeploymentName ($header + 'EGL Servers') `
#    -DeploymentType Required -TimeBasedOn UTC -UserNotification DisplaySoftwareCenterOnly `
#    -RequirePostRebootFullScan $true -DownloadFromMicrosoftUpdate $true -DeadlineDateTime $egl_start_time `
#    -CollectionID $EGL_SERVERS_COLLECTION -UseBranchCache $true -ProtectedType RemoteDistributionPoint

#New-CMSoftwareUpdateDeployment -SoftwareUpdateGroupName $sup -DeploymentName ($header + ' - SCCM Test Servers') `
#    -Description 'Patch Tuesday' -DeploymentType Required -TimeBasedOn UTC -UserNotification DisplaySoftwareCenterOnly `
#    -DeadlineDateTime $sccm_start_time -CollectionId 'SL200076' -whatif


Set-Location $startlocation # Puts us back in the original file location


#>