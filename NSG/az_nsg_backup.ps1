#### GET THE LIST OF SUBSCRIPTION AVAILABLE ####
Write-Verbose -Message ("{0} - {1}" -f (Get-Date).ToString(),"LIST OF AVAILABLE SUBSCRIPTIONS ARE GIVEN BELOW....")
$global:i=0
Get-AzSubscription | Select @{Name="Item";Expression={$global:i++;$global:i}},Name -OutVariable menu | format-table -AutoSize
$temp = $menu | select -ExpandProperty item
do {$r = Read-Host "Select a subscription to deploy VM in"} until ($r -in $temp)
$svc = $menu | where {$_.item -eq $r}
$sub = $svc.Name
Write-Host "Selected Subscription is $sub" -ForegroundColor Green


$Sub_ID = Get-AzSubscription | ? {$_.Name -eq $sub} | select -ExpandProperty id
Set-AzContext -Subscription $Sub_ID | Out-Null

Write-Host "The current subscription context is set to $sub" -ForegroundColor Green

$NSG_test = Get-AzNetworkSecurityGroup
$cnt = $NSG_test.Count
Write-Host "There are total $($cnt) NSGs under subscription $($sub)" -ForegroundColor DarkCyan

$index = 0
$final = @()
foreach ($x in $NSG_test)
    {
    
    $results = @()
    $NSG_name = $x.Name
    $Region = $x.Location
    $Rg_name = $x.ResourceGroupName
    $NSG_ID_Arr = $x.Id.Split('/')
    $Sub_ID_Index = 2
    $Sub_Name = Get-AzSubscription | ? {$_.Id -eq $NSG_ID_Arr[$Sub_ID_Index]} | select -ExpandProperty Name

    ### BELOW IS THE CONCATENATION OF SECURITY RULES TO ONE ARRAY OBJECT ####
    $Sec_Rule = $x.SecurityRules
    $Def_Sec_Rule = $x.DefaultSecurityRules
    $Sec_Rule += $Def_Sec_Rule

    foreach ($y in $Sec_Rule)

            {

            $Row2 = "" | Select NSG_Name, Region, Subscription, RG_name, Priority, Rule_Name, SourcePort, DestinationPort, Protocol, Source, Destination, Action,Direction    
            $Row2.NSG_Name = $NSG_name
            $Row2.Region = $Region
            $Row2.Subscription = $Sub_Name
            $Row2.RG_name = $Rg_name
            $Row2.Priority = $y.Priority
            $Row2.Rule_name = $y.Name
            [string]$Row2.SourcePort = $y | Select -ExpandProperty SourcePortRange
            [string]$Row2.DestinationPort = $y | Select -ExpandProperty DestinationPortRange
            $Row2.Protocol = $y.Protocol
            [string]$Row2.Source = $y | Select -ExpandProperty SourceAddressPrefix
            [string]$Row2.Destination = $y | Select -ExpandProperty DestinationAddressPrefix
            $Row2.Action = $y.Access
            $Row2.Direction = $y.Direction

            $results += $Row2
                    
            }
       
       Write-Host "Loop $($index): Remaining $($cnt - $index)" -ForegroundColor Red

       $index = $index + 1
       $final += $results

       
    
    }
##EXPORT THE REPORT IN CSV FORMAT
$final | Export-Csv ./$sub.csv -NoTypeInformation
