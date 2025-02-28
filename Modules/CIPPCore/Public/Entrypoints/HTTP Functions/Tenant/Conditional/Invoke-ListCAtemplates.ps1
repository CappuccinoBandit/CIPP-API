using namespace System.Net

Function Invoke-ListCAtemplates {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.ConditionalAccess.Read
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    Write-LogMessage -headers $Request.Headers -API $APINAME -message 'Accessed this API' -Sev 'Debug'

    # Write to the Azure Functions log stream.
    Write-Host 'PowerShell HTTP trigger function processed a request.'
    Write-Host $Request.query.id
    #Migrating old policies whenever you do a list
    $Table = Get-CippTable -tablename 'templates'
    $Imported = Get-CIPPAzDataTableEntity @Table -Filter "PartitionKey eq 'settings'"
    if ($Imported.CATemplate -ne $true) {
        $Templates = Get-ChildItem 'Config\*.CATemplate.json' | ForEach-Object {
            $Entity = @{
                JSON         = "$(Get-Content $_)"
                RowKey       = "$($_.name)"
                PartitionKey = 'CATemplate'
                GUID         = "$($_.name)"
            }
            Add-CIPPAzDataTableEntity @Table -Entity $Entity -Force
        }
        Add-CIPPAzDataTableEntity @Table -Entity @{
            CATemplate   = $true
            RowKey       = 'CATemplate'
            PartitionKey = 'settings'
        } -Force
    }
    #List new policies
    $Table = Get-CippTable -tablename 'templates'
    $Filter = "PartitionKey eq 'CATemplate'"
    $Templates = (Get-CIPPAzDataTableEntity @Table -Filter $Filter) | ForEach-Object {
        $data = $_.JSON | ConvertFrom-Json -Depth 100
        $data | Add-Member -NotePropertyName 'GUID' -NotePropertyValue $_.GUID -Force
        $data
    } | Sort-Object -Property displayName

    if ($Request.query.ID) { $Templates = $Templates | Where-Object -Property GUID -EQ $Request.query.id }

    $Templates = ConvertTo-Json -InputObject @($Templates) -Depth 100
    # Associate values to output bindings by calling 'Push-OutputBinding'.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $Templates
        })

}
