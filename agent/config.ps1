# Token ID and Token
$CF_Token_ID = ''
$CF_Token = ''

# Worker URL, Full Domain
$CF_Worker_URL = 'https://test.example.worker.dev/update'
$CF_Domain = 'test.example.com'

$CF_IPv4_Enabled = $true
$CF_IPv6_Enabled = $true

# Use script block that returns the public IP address.
# If those are specified, they will be used to obtain your public IPv4/v6 address
# Set to $null for not-specified.
$CF_IPv4_Update_Block = { return (Invoke-RestMethod -Uri 'https://ip4.seeip.org/json').ip }
#$CF_IPv6_Update_Block = { return (Invoke-RestMethod -Uri 'https://ip6.seeip.org/json').ip }

#$CF_IPv4_Update_Block = $null
$CF_IPv6_Update_Block = $null

# If the update URL is not specified, the script will try to obtain one from your NIC.
# Set to -1 for not-specified.
$CF_IPv4_NIC_Index = -1
$CF_IPv6_NIC_Index = -1
$CF_IPv6_NIC_Allow_LinkLocal = $false

# If both above are not specified, the script can auto detect public address from your NICs.
# Set $false to disable.
$CF_IPv4_NIC_Auto_Public = $true
$CF_IPv6_NIC_Auto_Public = $true

# If none are specified, the script will use the 'auto' way, which is the public IP used to access the Worker.