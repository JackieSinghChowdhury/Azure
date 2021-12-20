This is a powershell script which needs to be run from Azure shell after uploading.

**RUNTIME expectations** - During runtime of the script the list of available subscriptions are displayed in the console with an adjacent item number against each 
subscription in whichever tenant this script in executed. Once the item number aginst the subscription in entered the script starts executing and outputs a CSV file
containing the backup of all the Network Security groups present inside the selected subscription with each rule within that. below provided details will be extracted
for each rule:
  1) NSG_Name
  2) Region
  3) Subscription
  4) RG_name
  5) Priority
  6) Rule_Name
  7) SourcePort
  8) DestinationPort
  9) Protocol
  10) Source
  11) Destination
  12) Action
  13) Direction
