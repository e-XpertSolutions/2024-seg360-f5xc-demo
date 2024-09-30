Write-Output "Deleting domain $env:INFK_SUBDOMAIN.$env:INFK_DOMAIN"

$domain_id = (curl --silent --request GET `
        --url "https://api.infomaniak.com/1/product?service_name=domain&customer_name=$env:INFK_DOMAIN" `
        --header "Authorization: Bearer $env:INFK_TOKEN" | ConvertFrom-Json).data[0].id

$record_id = ((curl --silent --request GET `
            --url https://api.infomaniak.com/1/domain/$domain_id/dns/record `
            --header "Authorization: Bearer $env:INFK_TOKEN" | ConvertFrom-JSON).data | Where-Object source -eq "$env:INFK_SUBDOMAIN").id

$res = curl --silent --request DELETE `
    --url https://api.infomaniak.com/1/domain/$domain_id/dns/record/$record_id `
    --header "Authorization: Bearer $env:INFK_TOKEN"

return $res