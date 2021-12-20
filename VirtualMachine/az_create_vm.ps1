$VerbosePreference = "Continue"
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"....THIS IS A SCRIPT TO CREATE VIRTUAL MACHINE IN AZURE....")
# Verify Login
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Verifying the Azure login subscription status...")
if( -not $(Get-AzContext) ) 
{  
	Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Login to Azure subscription failed, no valid subscription found.")
	return 
}
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Login to Azure subscription successfully!")



#### GET THE LIST OF SUBSCRIPTION AVAILABLE ####
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"LIST OF AVAILABLE SUBSCRIPTIONS ARE GIVEN BELOW....")
$global:i=0
Get-AzSubscription | Select @{Name="Item";Expression={$global:i++;$global:i}},Name -OutVariable menu | format-table -AutoSize
$temp = $menu | select -ExpandProperty item
do {$r = Read-Host "Select a subscription to deploy VM in"} until ($r -in $temp)
$svc = $menu | where {$_.item -eq $r}
$sub = $svc.Name
Write-Host "Selected Subscription is $sub" -ForegroundColor Green

$TotalSub = $menu | select -ExpandProperty Name


$Sub_ID = Get-AzSubscription | ? {$_.Name -eq $sub} | select -ExpandProperty id
Set-AzContext -Subscription $Sub_ID


Write-Host "The current subscription context is set to $sub" -ForegroundColor Green

#### GET THE LIST OF RESOURCE GROUP WITHIN SUBSCRIPTION with AVAILABLE Vnet####
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"LIST OF AVAILABLE Resource group within $subName ARE GIVEN BELOW....")

$global:j=0
Get-AzResourceGroup | Select @{Name="Item1";Expression={$global:j++;$global:j}},ResourceGroupName -OutVariable menu1 | format-table -AutoSize
$temp1 = $menu1 | select -ExpandProperty item1
do {$r1 = Read-Host "Select a Resource Group to deploy VM in subscription $subName"} until ($r1 -in $temp1)
$svc1 = $menu1 | where {$_.item1 -eq $r1}
$RG = $svc1.ResourceGroupName
Write-Host "Selected Resource group is $RG" -ForegroundColor Green


### GET THE REGION RESOURCE GROUP BELONGS TO####
$Region = Get-AzResourceGroup -ResourceGroupName $RG | Select -ExpandProperty Location 
Write-Host "VM will be created in $Region region" -ForegroundColor Green

### VIRUAL NETWORK ####
# Verify the virtual network
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Checking for available virtual network within subscription $subName ")
$VNet = Get-AzVirtualNetwork | ?{$_.Location -eq $Region}
if ($null -eq $VNet)
{
    Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"No virtual network exist within in region $Region. CREATE ONE AND RESTART THE script...")
    exit

}
else 
{
	Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Below is the list of Virtual network existing within subscription $subName and region $Region")
   
    
$global:k=0
$Vnet| Select @{Name="Item2";Expression={$global:k++;$global:k}},Name -OutVariable menu2 | format-table -AutoSize
$temp2 = $menu2 | select -ExpandProperty item2
do {$r2 = Read-Host "Select a Virtual Network to associate with VM: "} until ($r2 -in $temp2)
$svc2 = $menu2 | where {$_.item2 -eq $r2}
$VNet_Name = $svc2.Name
Write-Host "Selected Virtual Network is $VNet_Name" -ForegroundColor Green

#### GET THE LIST OF SUBNETS within this Virtual Network ####
$VirNet = Get-AzVirtualNetwork -Name $VNet_Name
$Subnets = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VirNet

Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Below is the list of SUBNETS part of Vnet $VNet_Name")
$global:l=0
$Subnets | Select @{Name="Item3";Expression={$global:l++;$global:l}},Name -OutVariable menu3 | format-table -AutoSize
$temp3 = $menu3 | select -ExpandProperty item3
do {$r3 = Read-Host "Select a SUBNET to deploy VM in VNET $VNet_Name"} until ($r3 -in $temp3)
$svc3 = $menu3 | where {$_.item3 -eq $r3}
$SubnetName = $svc3.Name
Write-Host "Selected SUBNET is $SubnetName" -ForegroundColor Green
$Subnet = Get-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $VirNet
}


##$Subnet.Id
###### DISPLAY ALL THE VALUES SELECTED BEFORE PROCEEDING TO CREATE VM ######
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"BELOW MENTIONED ARE THE SELECTED VALUES")

Write-Host " ########## BELOW LISTED OPTIONS SELECTED TO DEPLOY VM ########## "
Write-Host "Subscription  : $sub"
Write-Host "Resource Group: $RG"
Write-Host "Virual Network: $VNet_Name"
Write-Host "SUBNET        : $SubnetName"
Write-Host " ################################################################ "

do {$user_choice = Read-Host "Do you want to continue to CREATE VM (Yes/No): "} until (($user_choice -eq "Yes") -or ($user_choice -eq "No"))

If ($user_choice -eq "Yes")
    {
    Write-Host "Proceeding with creation of new VM" -ForegroundColor Gray
    }
elseif ($user_choice -eq "No")
    {
    Write-Host "User chose not to create VM. EXITING script in 10 seconds...." -ForegroundColor Red
    Start-Sleep -s 10
    exit
    }

### User input for VM Name #####
$VMName = Read-Host "Enter a valid VM Name: "
# Verify VM doesn't exist
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Checking the $VMName VM existance...")
$VM = Get-AzVM -Name $VMName -ErrorAction SilentlyContinue
if($null -ne $VM)
{
	Write-Error "$VMName VM already exists in $sub subscription, exiting..."
	##return
exit
}
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"No VM found with the name $VMName.")

# Create user object
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Obtaining the VM login credentials...")

    [pscredential] $VMCredential = Get-Credential -Message 'Please enter the vm credentials'

# Verify credential
if ($VMCredential.GetType().Name -ne "PSCredential")
{
    Write-Error "No valid credential found, exiting..."
    return
}
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Obtained valid VM login credentials")

############################################# >


######################## NIC CREATION STEPS #########
  $cur1 = Get-Date
################################### Create a virtual network card and associate with NSG
[string] $NICName = "$VMName-nic"
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Verifying the network interface card $NICName existance")
$NIC = Get-AzNetworkInterface -Name $NICName -ErrorAction SilentlyContinue
if ($null -ne $NIC)
    {
	$NICName = $VMName + "-nic-" + $(Get-Random).ToString()
	Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"$($NIC.Name) NIC already exists, and creating a new NIC $NICName")
$NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $RG -Location $Region -SubnetId $Subnet.Id
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"New $NICName NIC is created.")

    }
else
    {
## Creating NIC with VMName as prefix
$NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $RG -Location $Region -SubnetId $Subnet.Id
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"New $NICName NIC is created.")
    }

$end1 = Get-Date
$diff1 = New-TimeSpan -Start $cur1 -End $end1

###### DISPLAY ALL THE VALUES SELECTED BEFORE PROCEEDING TO CREATE VM ######
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"BELOW MENTIONED ARE THE SELECTED VALUES")

Write-Host " ########## BELOW LISTED OPTIONS SELECTED TO DEPLOY VM ########## "
Write-Host "Subscription  : $subName"
Write-Host "Resource Group: $RG"
Write-Host "Virual Network: $VNet_Name"
Write-Host "SUBNET        : $SubnetName"
Write-Host "NIC           : $NICName"
Write-Host " ################################################################ "

###### END OF DISPLAY #####################################################

### NEED TO SELECT THE DISK - For OS disk ask user for Disk type and for data disk ask user if they want to create one #####

### SELECT VM Size

# VM Size
$Avail_VMSize = Get-AzVMSize -Location $Region
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"BELOW IS THE LIST OF VMSIZE AVAILABLE FOR REGION $Region")
##$Avail_VMSize
$global:n=0
$Avail_VMSize | Select @{Name="Item5";Expression={$global:n++;$global:n}},Name -OutVariable menu5 | format-table -AutoSize
$temp5 = $menu5 | select -ExpandProperty item5
do {$r5 = Read-Host "Select a VMSize from above list: "} until ($r5 -in $temp5)
$svc5 = $menu5 | where {$_.item5 -eq $r5}
$VMSize = $svc5.Name

Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Selecting the VMSize:$VMSize")

$Type = @()
$OSDiskType_array = @('Standard_LRS', 'Premium_LRS', 'StandardSSD_LRS')
foreach($x in $OSDiskType_array){$outcome1 = '' | select Name;$outcome1.Name = $x ; $Type += $outcome1}
    $global:x=0
    $Type | Select @{Name="Item10";Expression={$global:x++;$global:x}},Name -OutVariable menu10 | format-table -AutoSize
    $temp10 = $menu10 | select -ExpandProperty item10
    do {$r10 = Read-Host "Select OS Disk Type"} until ($r10 -in $temp10)
    $svc10 = $menu10 | where {$_.item10 -eq $r10}
    $TypeName = $svc10.Name


###### Ask user if Data Disk is required ######
do {$DiskChoice = Read-Host "Do you need to attach data disk(Yes/No)?"} until (($DiskChoice -eq 'Yes') -or ($DiskChoice -eq 'No'))
$cur2 = Get-Date
if($DiskChoice -eq 'Yes')
    {
    do {
        write-host -nonewline "Enter the number of Data Disk needed: "
        $inputString = read-host 
        $value = $inputString -as [long]
        $ok = $value -ne $NULL
        if ( -not $ok ) { write-host "You must enter a numeric value" }
        }
        until ( $ok )
    write-host "You entered: $value"
    $new_array = @('Standard_LRS', 'Premium_LRS', 'StandardSSD_LRS')
    
    $add_Ddisk = @()
    
    for ($init = 1; $init -le $value; $init++)
    {
    $Disk_SKU = @()
    foreach($z in $new_array){$outcome = '' | select Name;$outcome.Name = $z ; $Disk_SKU += $outcome}
    $global:z=0
    $Disk_SKU | Select @{Name="Item8";Expression={$global:z++;$global:z}},Name -OutVariable menu8 | format-table -AutoSize
    $temp8 = $menu8 | select -ExpandProperty item8
    do {$r8 = Read-Host "Select a Data Disk storage type from above list for data disk number $init : "} until ($r8 -in $temp8)
    $svc8 = $menu8 | where {$_.item8 -eq $r8}
    $DataDiskSKU = $svc8.Name
    $dataDiskName = $VMName + "-DataDisk-" + $init + (Get-Random).ToString()
    Write-Host "Selected data disk is $DataDiskSKU"

    do {
        write-host -nonewline "What should be the Data Disk size: "
        $inputString1 = read-host 
        $value1 = $inputString1 -as [long]
        $ok1 = $value1 -ne $NULL
        if ( -not $ok1 ) { write-host "You must enter a numeric value" }
        }
        until ( $ok1 )
    write-host "You entered: $value1"
        
    $diskConfig = New-AzDiskConfig -SkuName $DataDiskSKU -Location $Region -CreateOption Empty -DiskSizeGB $value1
    $dataDisk = New-AzDisk -DiskName $dataDiskName -Disk $diskConfig -ResourceGroupName $RG
    

    Remove-Variable -Name menu8
    Remove-Variable -Name r8
    Remove-Variable -Name temp8
    Remove-Variable -Name DataDiskSKU
    Remove-Variable -Name svc8

    }
    $add_Ddisk += $datadisk.Name
    } 
$end2 = Get-Date
$diff2 = New-TimeSpan -Start $cur2 -End $end2
$time = $diff1.Add($diff2)

$total_data_disk = Get-AzDisk | ? {$_.Name -in $add_Ddisk}


#### Select the VM Image ####
# OS Type


[hashtable] $VMSourceImage = @{PublisherName='';Offer='';Skus=''}
$Img_Gallery = Get-AzGallery
            if ($null -eq $Img_Gallery)
                {
                Write-Host "There is no Shared Image in subscription $sub...Selecting Image from market place..." -ForegroundColor DarkYellow

                #### FIND IMAGE
                $ImgPub = Get-AzVMImagePublisher -Location $Region | ?{$_.PublisherName -eq "MicrosoftWindowsDesktop" -or $_.PublisherName -eq "MicrosoftWindowsServer" -or $_.PublisherName -eq "MicrosoftSQLServer"}
                $ImgOffer = $ImgPub | Get-AzVMImageOffer | ? {$_.Offer -notlike '*ubuntu*' -and $_.Offer -notlike '*rhel*' -and $_.Offer -notlike '*linux*'}
                $ImgSKU = $ImgOffer | Get-AzVMImageSku
                ###### END #####
                
                #### Selecting SKU for Windows OS
                $global:o1=0
                $ImgSKU | Select @{Name="Item_6";Expression={$global:o1++;$global:o1}},Skus,Offer,PublisherName -OutVariable menu_6 | format-table -AutoSize
                $temp_6 = $menu_6 | select -ExpandProperty item_6
                do {$r_6 = Read-Host "Select an Image from above list: "} until ($r_6 -in $temp_6)
                $svc_6 = $menu_6 | where {$_.item_6 -eq $r_6}
                $SKU_Name = $svc_6.Skus
                $SKU_Offer = $svc_6.Offer
                $SKU_PubName = $svc_6.PublisherName 

                Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Selecting the SKU: $SKU_Name")

                $VMSourceImage.PublisherName = $SKU_PubName
			    $VMSourceImage.Offer = $SKU_Offer
			    $VMSourceImage.Skus = $SKU_Name

                }
            else
                { 
                $global:o=0
                $Img_Gallery | Select @{Name="Item6";Expression={$global:o++;$global:o}},Name -OutVariable menu6 | format-table -AutoSize
                $temp6 = $menu6 | select -ExpandProperty item6
                do {$r6 = Read-Host "Select a Shared Image Gallery Name from above list: "} until ($r6 -in $temp6)
                $svc6 = $menu6 | where {$_.item6 -eq $r6}
                $GalleryName = $svc6.Name

                Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Selecting the Gallery:$GalleryName")

                
            ## Selecting the Image Definition ###
            $Img_RG = ($Img_Gallery | ? {$_.name -eq $GalleryName}) | select -ExpandProperty ResourceGroupName
            $Img_Def = Get-AzGalleryImageDefinition -ResourceGroupName $Img_RG -GalleryName $GalleryName | ? {$_.OsType -eq $OSType}
            $global:p=0
            $Img_Def | Select @{Name="Item7";Expression={$global:p++;$global:p}},@{Name="ImageSKU";Expression={$_.Identifier.Sku}},Name -OutVariable menu7 | format-table -AutoSize
            $temp7 = $menu7 | select -ExpandProperty item7
            do {$r7 = Read-Host "Select a VM Image SKU from above list: "} until ($r7 -in $temp7)
            $svc7 = $menu7 | where {$_.item7 -eq $r7}
            $SharedImgName = $svc7.Name

            Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Selecting the Shared Image named:$SharedImgName")
            $ImgSrc = $Img_Def | ? {$_.Name -eq $SharedImgName}

            $VMSourceImage.PublisherName = $ImgSrc.Identifier.Publisher
			$VMSourceImage.Offer = $ImgSrc.Identifier.Offer
			$VMSourceImage.Skus = $ImgSrc.Identifier.Sku


                }

##################### VM Config - BEGIN #####
$cur3 = Get-Date
# Create a virtual machine configuration
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Configuring $VMName VM...")
$VMConfig = New-AzVMConfig -VMName $VMName -VMSize $VMSize 



Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Choosing VMSize:$VMSize")
$VMConfig | Set-AzVMOperatingSystem -Windows -ComputerName $VMName -Credential $VMCredential | Out-Null

$VMSourceImage
$OSDiskName = $VMName + "-OSDISK-" + $(Get-Random).ToString()
$VMConfig | Set-AzVMSourceImage -PublisherName $VMSourceImage.PublisherName -Offer $VMSourceImage.Offer -Skus $VMSourceImage.Skus -Version latest | Out-Null
$VMConfig = Set-AzVMOSDisk -VM $VMConfig -Name $OSDiskName -Caching ReadWrite -Windows -CreateOption fromimage -storageaccounttype $TypeName
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Configuring $OSType VM...")
$VMConfig | Add-AzVMNetworkInterface -Id $NIC.Id | Out-Null
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Configuring NIC...")
$end3 = Get-Date
$diff3= New-TimeSpan -Start $cur3 -End $end3
$time = $time.Add($diff3)
## SELECT STORAGE ACCOUNT TO STORE BOOT DIAGNOSTIC LOG ####

do {$bootdiag_choice = Read-Host "Do you want to enable BOOT DIAGNOSTIC for $VMName (Yes/No)"} until (($bootdiag_choice -eq 'Yes') -or ($bootdiag_choice -eq 'No'))

if ($bootdiag_choice -eq "Yes")
{
$st_accounts = Get-AzStorageAccount

$stacclist = $st_accounts | select -ExpandProperty StorageAccountName
$stacc = @('stdiagmoveitwe','stdiagsvcapac','stdiagsvceu','stdiagsvcwew','stdiagtcwe','stdiagwcwe','stdiagviewap','stdiagvieweu','stdiagviewwe')
$stcompare = Compare-Object -ReferenceObject $stacclist -DifferenceObject $stacc -ExcludeDifferent
$endresult = $stcompare.inputobject
# Set boot diagnostic storage account
if ($null -eq $endresult)
    {
    Write-Host "There is no storage account associated with subscription $sub which match the following accounts: $stacc " -ForegroundColor DarkYellow
    Write-Host "Finding available storage accounts within $sub " -ForegroundColor Magenta
    ##$stacclist = Get-AzStorageAccount | select StorageAccountName
    $global:q1=0
    $st_accounts | Select @{Name="Item11";Expression={$global:q1++;$global:q1}},StorageAccountName, ResourceGroupName -OutVariable menu11 | format-table -AutoSize
    $temp11 = $menu11 | select -ExpandProperty item11
    do {$r11 = Read-Host "Select the storage account from list above"} until ($r11 -in $temp11)
    $svc11 = $menu11 | where {$_.item11 -eq $r11}
    $st_name = $svc11.StorageAccountName
    $st_RG = $svc11.ResourceGroupName
    
    
    Write-Host "Selected storage account is $st_name" -ForegroundColor Gray
    $cur4 = Get-Date
    Set-AzVMBootDiagnostic -Enable -ResourceGroupName $st_RG -VM $VMConfig -StorageAccountName $st_name
    $end4 = Get-Date
    $diff4= New-TimeSpan -Start $cur4 -End $end4
    $time = $time.Add($diff4)
    Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Configuring boot diagnostics...")

    }
else
    {
    $st_arr = @()
    foreach($q in $endresult){$outcome3 = '' | select StorageAccountName;$outcome3.StorageAccountName = $q ; $st_arr += $outcome3}
    $global:q1=0
    $st_arr | Select @{Name="Item11";Expression={$global:q1++;$global:q1}},StorageAccountName -OutVariable menu11 | format-table -AutoSize
    $temp11 = $menu11 | select -ExpandProperty item11
    do {$r11 = Read-Host "Select the storage account from list above"} until ($r11 -in $temp11)
    $svc11 = $menu11 | where {$_.item11 -eq $r11}
    $st_name = $svc11.StorageAccountName
    $st_RG = Get-AzStorageAccount | ?{$_.StorageAccountName -eq $st_name} | select -ExpandProperty ResourceGroupName
    
    Write-Host "Selected storage account is $st_name" -ForegroundColor Gray 
    
    $cur4 = Get-Date
    
    Set-AzVMBootDiagnostic -Enable -ResourceGroupName $st_RG -VM $VMConfig -StorageAccountName $st_name
    $end4 = Get-Date
    $diff4= New-TimeSpan -Start $cur4 -End $end4
    $time = $time.Add($diff4)

    Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Configuring boot diagnostics...")
    }
   }
   else
    {
    Write-Host "User opted to not enable BOOT DIAGNOSTIC for $VMName" -ForegroundColor Magenta
    }
#### TAG for NEW VM
do {$tag_choice = Read-Host "Do you want to create TAG for $VMName (Yes/No)"} until (($tag_choice -eq 'Yes') -or ($tag_choice -eq 'No'))

if ($tag_choice -eq 'Yes')
    {
    $GrpID = Read-Host "Enter GCID"
    $CCenter = Read-Host "Enter the CostCenter"
    $environ = Read-Host "Enter environment Name"
    $app = Read-Host "Enter application Name"
    $own = Read-Host "Enter owner Email ID"
    $org = Read-Host "Enter organizantion Name"
    $aID = Read-Host "Enter App ID"    
    $OperSys = Read-Host "Enter Operating System Name"
    
    $tag = @{ "AppID" = "$aID";"ApplicationName" = "$app";"Cost Center" = "$CCenter";"Environment" = "$environ";"GCID" = $GrpID;"Organization"= "$org";"OS"= "$OperSys";"Owner" = "$own"}
    }

##$current = Get-Date
# Create a virtual machine
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"$VMName VM deployement started.")
if ($tag_choice -eq 'Yes')
    {
    $cur5 = Get-Date
    New-AzVM -ResourceGroupName $RG -Location $Region -VM $VMConfig -Tag $tag
    
    ## Check for VM Creation status
        if ($? -eq 'True')
            {
            Write-Host "$VMName VM successfully created ..." -ForegroundColor Black -BackgroundColor White
        
            }
        else
            {
            Write-Host "$VMName could not be created as there was some error while creating..." -ForegroundColor Red -BackgroundColor Yellow
            }
    $VM_err = $Error[0] 
    $end5 = Get-Date
    $diff5= New-TimeSpan -Start $cur5 -End $end5
    $time = $time.Add($diff5)
    }
else 
    {
    $cur5 = Get-Date
    New-AzVM -ResourceGroupName $RG -Location $Region -VM $VMConfig
    ## Check for VM Creation status
        if ($? -eq 'True')
            {
            Write-Host "$VMName VM successfully created ..." -ForegroundColor Black -BackgroundColor White
        
            }
        else
            {
            Write-Host "$VMName could not be created as there was some error while creating..." -ForegroundColor Red -BackgroundColor Yellow
            }
    $VM_err = $Error[0] 
    $end5 = Get-Date
    $diff5= New-TimeSpan -Start $cur5 -End $end5
    $time = $time.Add($diff5)
    }

## Attach Data Disk in VM

    if($DiskChoice -eq 'Yes')
        {
        $lun = 1
        $cur6 = Get-Date
        foreach ($td in $total_data_disk)
            {
            $vm = Get-AzVM -Name $VMName -ResourceGroupName $RG
            $vm = Add-AzVMDataDisk -VM $vm -Name $td.Name -CreateOption Attach -ManagedDiskId $td.Id -Lun $lun

            Update-AzVM -VM $vm -ResourceGroupName $RG 
            $lun++
            }
            $end6 = Get-Date
            $diff6 = New-TimeSpan -Start $cur6 -End $end6
            $time = $time.Add($diff6)
            }
    else
        {
          $vm = Get-AzVM -Name $VMName -ResourceGroupName $RG 
        }

##### Configure BACKUP for the VM ###

if ($null -eq $vm)
    {
    Write-Host "VM $VMName failed to get created... Error details provided below...." -ForegroundColor Red -BackgroundColor White
    Write-Host "$VM_err"

    }
else
    {
    
    do {$bkp_choice = Read-Host "Do you want to create BACKUP for $VMName (Yes/No)"} until (($bkp_choice -eq 'Yes') -or ($bkp_choice -eq 'No'))

    if ($bkp_choice -eq "Yes")
    {
    $Rec_vaults = Get-AzRecoveryServicesVault | ?{$_.Location -eq $vm.Location}
    Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Below is the list of Recovery vaults par of subscription $sub")
    $global:bkp1=0
    $Rec_vaults | Select @{Name="Item13";Expression={$global:bkp1++;$global:bkp1}},Name -OutVariable menu13 | format-table -AutoSize
    $temp13 = $menu13 | select -ExpandProperty item13
    do {$r13 = Read-Host "Select a recovery vault from list above"} until ($r13 -in $temp13)
    $svc13 = $menu13 | where {$_.item13 -eq $r13}
    $RV_name = $svc13.Name
    
    ## CHECK IF THE RECOVERY SERVICE VAULT ALREADY HAS THE SERVER NAME PROTECTED UNDER ANY POLICY
    $vault = Get-AzRecoveryServicesVault -Name $RV_name
    $bkp = Get-AzRecoveryServicesBackupContainer -FriendlyName $VMName -ContainerType AzureVm -VaultId $vault.ID -Status Registered
    if ($bkp -ne $null)
        {
        Write-Host "$VMName is already a part of Recovery Service Vault $RV_name" -ForegroundColor DarkYellow
        }
    else
        {    
        Write-Host "Selected recovery vault for backup is $RV_name" -ForegroundColor Gray
        $vault | Set-AzRecoveryServicesVaultContext

    

        $Policy = Get-AzRecoveryServicesBackupProtectionPolicy | ? {$_.WorkloadType -eq 'AzureVM'}  | select Name

        ## Ask user to select policy ###
    
        $global:bkp2=0
        $Policy | Select @{Name="Item14";Expression={$global:bkp2++;$global:bkp2}},Name -OutVariable menu14 | format-table -AutoSize
        $temp14 = $menu14 | select -ExpandProperty item14
        do {$r14 = Read-Host "Select a Policy from list above"} until ($r14 -in $temp14)
        $svc14 = $menu14 | where {$_.item14 -eq $r14}
        $Policy_name = $svc14.Name

        $sel_policy = Get-AzRecoveryServicesBackupProtectionPolicy -Name $Policy_name

        Write-Host "Selected Policy for backup is $Policy_name under recovery vault $RV_name" -ForegroundColor Gray
        $cur7 = Get-Date
        Enable-AzRecoveryServicesBackupProtection -ResourceGroupName $RG -Name $VMName -Policy $sel_policy
        $end7 = Get-Date
        $diff7 = New-TimeSpan -Start $cur7 -End $end7
        $time = $time.Add($diff7)
        Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"Configuring Backup...")
        }
    }
    else
        {
        Write-Host "User opted to not create backup for $VMName" -ForegroundColor Magenta
        }
    }

### BACKUP configuration END ###

$DAYS = $time.Days
$HR = $time.Hours
$min = $time.Minutes
$sec = $time.Seconds


##Write-Host "VM has been successfully deployed" -ForegroundColor DarkGreen
Write-Host "The script ran for $DAYS DAYS $HR hours $min minutes $sec seconds" -ForegroundColor White -BackgroundColor Black
