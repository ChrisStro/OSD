function Test-MyDellBiosWebConnection {
    [CmdletBinding()]
    param ()
    
    $GetMyDellBios = Get-MyDellBios
    if ($GetMyDellBios) {
        Test-WebConnection -Uri $GetMyDellBios.Url
    } else {
        Return $false
    }
}
function Test-WebConnectionMsUpCat {
    [CmdletBinding()]
    param ()

    if (Test-WebConnection -Uri 'https://www.catalog.update.microsoft.com/Home.aspx') {
        Return $true
    } else {
        Return $false
    }
}