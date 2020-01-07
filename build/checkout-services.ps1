param (
  [string]$connectionString = ""
)

function AcquireLease($blob) {
  try {
    return $blob.ICloudBlob.AcquireLease($null, $null, $null, $null, $null)    
  } catch {
    Write-Host "  Error: $_"
    return $null
  } 
}

# get a blob lease to prevent test overlap
$storageContext = New-AzureStorageContext -ConnectionString $connectionString
While($true) {
  $blobs = Get-AzureStorageBlob -Context $storageContext -Container "ci-locks"
  $token = $null
  
  # shuffle the blobs for random ordering
  $blobs = $blobs | Sort-Object {Get-Random}

  Write-Host "Looking for unleased ci-lock blobs (list is shuffled):"
  Foreach ($blob in $blobs) {
    $name = $blob.Name
    $leaseStatus = $blob.ICloudBlob.Properties.LeaseStatus
    
    Write-Host "  ${name}: $leaseStatus"
    
    if ($leaseStatus -eq "Locked") {
      continue
    }

    Write-Host "  Attempting to acquire lease on $name."
    $token = AcquireLease $blob
    if ($token -ne $null) {
      Write-Host "  Lease acquired on $name. LeaseId: '$token'"
      Write-Host "##vso[task.setvariable variable=LeaseBlob]$name"
      Write-Host "##vso[task.setvariable variable=LeaseToken]$token"
      break
    } else {
      Write-Host "  Lease not acquired on $name."
    }    
  }
  
  if ($token -ne $null) {
    break
  }
  
  $delay = 30
  Write-Host "No lease acquired. Waiting $delay seconds to try again. This run cannot begin until it acquires a lease on a CI test environment."
  Start-Sleep -s $delay
  Write-Host ""
}