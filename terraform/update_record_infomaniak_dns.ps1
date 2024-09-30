Write-Output "Adding record for domain $env:INFK_SUBDOMAIN.$env:INFK_DOMAIN to target $env:INFK_TARGET"

$domain_id = (curl --silent --request GET `
    --url "https://api.infomaniak.com/1/product?service_name=domain&customer_name=$env:INFK_DOMAIN" `
    --header "Authorization: Bearer $env:INFK_TOKEN" | ConvertFrom-Json).data[0].id

$request_data = @"
{
  "type": "$env:INFK_RECORD_TYPE",
  "source": "$env:INFK_SUBDOMAIN",
  "target": "$env:INFK_TARGET",
  "ttl": 300
}
"@

$res = curl --silent --request POST `
  --url "https://api.infomaniak.com/1/domain/$domain_id/dns/record" `
  --header "Authorization: Bearer $env:INFK_TOKEN" `
  --header "Content-Type: application/json" `
  --data $request_data

return $res