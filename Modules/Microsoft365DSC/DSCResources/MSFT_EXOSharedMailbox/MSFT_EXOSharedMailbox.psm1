function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $DisplayName,

        [Parameter()]
        [System.String]
        $PrimarySMTPAddress,

        [Parameter()]
        [System.String[]]
        $Aliases,

        [Parameter()]
        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure = "Present",

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [System.String]
        $CertificatePath,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $CertificatePassword
    )

    Write-Verbose -Message "Getting configuration of Office 365 Shared Mailbox $DisplayName"
    if ($Global:CurrentModeIsExport)
    {
        $ConnectionMode = New-M365DSCConnection -Workload 'ExchangeOnline' `
            -InboundParameters $PSBoundParameters `
            -SkipModuleReload $true
    }
    else
    {
        $ConnectionMode = New-M365DSCConnection -Workload 'ExchangeOnline' `
            -InboundParameters $PSBoundParameters
    }

    #Ensure the proper dependencies are installed in the current environment.
    Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName -replace "MSFT_", ""
    $CommandName  = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    $nullReturn = $PSBoundParameters
    $nullReturn.Ensure = "Absent"

    try
    {
        $mailbox = Get-Mailbox -Identity $DisplayName `
                               -RecipientTypeDetails "SharedMailbox" `
                               -ResultSize Unlimited `
                               -ErrorAction Stop

        if ($null -eq $mailbox)
        {
            Write-Verbose -Message "The specified Shared Mailbox doesn't already exist."
            return $nullReturn
        }

        #region Email Aliases
        $CurrentAliases = @()

        foreach ($email in $mailbox.EmailAddresses)
        {
            $emailValue = $email.Split(":")[1]
            if ($emailValue -and $emailValue -ne $mailbox.PrimarySMTPAddress)
            {
                $CurrentAliases += $emailValue
            }
        }
        #endregion

        $result = @{
            DisplayName           = $DisplayName
            PrimarySMTPAddress    = $mailbox.PrimarySMTPAddress.ToString()
            Aliases               = $CurrentAliases
            Ensure                = "Present"
            Credential    = $Credential
            ApplicationId         = $ApplicationId
            CertificateThumbprint = $CertificateThumbprint
            CertificatePath       = $CertificatePath
            CertificatePassword   = $CertificatePassword
            TenantId              = $TenantId
        }

        Write-Verbose -Message "Found an existing instance of Shared Mailbox '$($DisplayName)'"
        return $result
    }
    catch
    {
        try
        {
            Write-Verbose -Message $_
            $tenantIdValue = ""
            if (-not [System.String]::IsNullOrEmpty($TenantId))
            {
                $tenantIdValue = $TenantId
            }
            elseif ($null -ne $Credential)
            {
                $tenantIdValue = $Credential.UserName.Split('@')[1]
            }
            Add-M365DSCEvent -Message $_ -EntryType 'Error' `
                -EventID 1 -Source $($MyInvocation.MyCommand.Source) `
                -TenantId $tenantIdValue
        }
        catch
        {
            Write-Verbose -Message $_
        }
        return $nullReturn
    }
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $DisplayName,

        [Parameter()]
        [System.String]
        $PrimarySMTPAddress,

        [Parameter()]
        [System.String[]]
        $Aliases = @(),

        [Parameter()]
        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure = "Present",

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [System.String]
        $CertificatePath,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $CertificatePassword
    )

    Write-Verbose -Message "Setting configuration of Office 365 Shared Mailbox $DisplayName"
    #Ensure the proper dependencies are installed in the current environment.
    Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName -replace "MSFT_", ""
    $CommandName  = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    $currentMailbox = Get-TargetResource @PSBoundParameters

    #region Validation
    foreach ($alias in $Aliases)
    {
        if ($alias.ToLower() -eq $PrimarySMTPAddress.ToLower())
        {
            throw "You cannot have the Aliases list contain the PrimarySMTPAddress"
        }
    }
    #endregion

    $CurrentParameters = $PSBoundParameters
    $ConnectionMode = New-M365DSCConnection -Workload 'ExchangeOnline' `
        -InboundParameters $PSBoundParameters

    # CASE: Mailbox doesn't exist but should;
    if ($Ensure -eq "Present" -and $currentMailbox.Ensure -eq "Absent")
    {
        Write-Verbose -Message "Shared Mailbox '$($DisplayName)' does not exist but it should. Creating it."
        $emails = ""
        foreach ($alias in $Aliases)
        {
            $emails += $alias + ","
        }
        $emails += $PrimarySMTPAddress
        $proxyAddresses = $emails -Split ','
        $CurrentParameters.Aliases = $proxyAddresses
        New-MailBox -Name $DisplayName -PrimarySMTPAddress $PrimarySMTPAddress -Shared:$true
        Set-Mailbox -Identity $DisplayName -EmailAddresses @{add = $Aliases }
    }
    # CASE: Mailbox exists but it shouldn't;
    elseif ($Ensure -eq "Absent" -and $currentMailbox.Ensure -eq "Present")
    {
        Write-Verbose -Message "Shared Mailbox '$($DisplayName)' exists but it shouldn't. Deleting it."
        Remove-Mailbox -Identity $DisplayName -Confirm:$false
    }
    # CASE: Mailbox exists and it should, but has different values than the desired ones
    elseif ($Ensure -eq "Present" -and $currentMailbox.Ensure -eq "Present")
    {
        # CASE: Email Aliases need to be updated
        Write-Verbose -Message "Shared Mailbox '$($DisplayName)' already exists, but needs updating."
        $current = $currentMailbox.Aliases
        $desired = $Aliases
        $diff = Compare-Object -ReferenceObject $current -DifferenceObject $desired
        if ($diff)
        {
            # Add Aliases
            Write-Verbose -Message "Updating the list of Aliases for the Shared Mailbox '$($DisplayName)'"
            $emails = ""
            $aliasesToAdd = $diff | Where-Object -FilterScript { $_.SideIndicator -eq '=>' }
            if ($null -ne $aliasesToAdd)
            {
                $emailsToAdd = ''
                foreach ($alias in $aliasesToAdd)
                {
                    $emailsToAdd += $alias.InputObject + ","
                }
                $emailsToAdd += $PrimarySMTPAddress
                $proxyAddresses = $emailsToAdd -Split ','

                Write-Verbose -Message "Adding the following email aliases: $emailsToAdd"
                Set-Mailbox -Identity $DisplayName -EmailAddresses @{add = $proxyAddresses }
            }
            # Remove Aliases
            $aliasesToRemove = $diff | Where-Object -FilterScript { $_.SideIndicator -eq '<=' }
            if ($null -ne $aliasesToRemove)
            {
                $emailsToRemoved = ''
                foreach ($alias in $aliasesToRemove)
                {
                    $emailsToRemoved += $alias.InputObject + ","
                }
                $emailsToRemoved += $PrimarySMTPAddress
                $proxyAddresses = $emailsToRemoved -Split ','

                Write-Verbose -Message "Removing the following email aliases: $emailsToRemoved"
                Set-Mailbox -Identity $DisplayName -EmailAddresses @{remove = $proxyAddresses }
            }
        }
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $DisplayName,

        [Parameter()]
        [System.String]
        $PrimarySMTPAddress,

        [Parameter()]
        [System.String[]]
        $Aliases,

        [Parameter()]
        [ValidateSet("Present", "Absent")]
        [System.String]
        $Ensure = "Present",

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [System.String]
        $CertificatePath,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $CertificatePassword
    )
    #Ensure the proper dependencies are installed in the current environment.
    Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName -replace "MSFT_", ""
    $CommandName  = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    Write-Verbose -Message "Testing configuration of Office 365 Shared Mailbox $DisplayName"

    $CurrentValues = Get-TargetResource @PSBoundParameters

    Write-Verbose -Message "Current Values: $(Convert-M365DscHashtableToString -Hashtable $CurrentValues)"
    Write-Verbose -Message "Target Values: $(Convert-M365DscHashtableToString -Hashtable $PSBoundParameters)"

    $TestResult = Test-M365DSCParameterState -CurrentValues $CurrentValues `
        -Source $($MyInvocation.MyCommand.Source) `
        -DesiredValues $PSBoundParameters `
        -ValuesToCheck @("Ensure", `
            "DisplayName", `
            "PrimarySMTPAddress",
        "Aliases")

    Write-Verbose -Message "Test-TargetResource returned $TestResult"

    return $TestResult
}

function Export-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.String]
        $ApplicationId,

        [Parameter()]
        [System.String]
        $TenantId,

        [Parameter()]
        [System.String]
        $CertificateThumbprint,

        [Parameter()]
        [System.String]
        $CertificatePath,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $CertificatePassword
    )
    $ConnectionMode = New-M365DSCConnection -Workload 'ExchangeOnline' `
        -InboundParameters $PSBoundParameters `
        -SkipModuleReload $true

    #Ensure the proper dependencies are installed in the current environment.
    Confirm-M365DSCDependencies

    #region Telemetry
    $ResourceName = $MyInvocation.MyCommand.ModuleName -replace "MSFT_", ""
    $CommandName  = $MyInvocation.MyCommand
    $data = Format-M365DSCTelemetryParameters -ResourceName $ResourceName `
        -CommandName $CommandName `
        -Parameters $PSBoundParameters
    Add-M365DSCTelemetryEvent -Data $data
    #endregion

    try
    {
        [array]$mailboxes = Get-Mailbox -RecipientTypeDetails "SharedMailbox" `
            -ResultSize Unlimited `
            -ErrorAction Stop
        $dscContent = ''
        $i = 1
        if ($mailboxes.Length -eq 0)
        {
            Write-Host $Global:M365DSCEmojiGreenCheckMark
        }
        else
        {
            Write-Host "`r`n" -NoNewline
        }
        foreach ($mailbox in $mailboxes)
        {
            Write-Host "    |---[$i/$($mailboxes.Length)] $($mailbox.Name)" -NoNewline
            $mailboxName = $mailbox.Name
            if ($mailboxName)
            {
                $params = @{
                    Credential    = $Credential
                    DisplayName           = $mailboxName
                    ApplicationId         = $ApplicationId
                    TenantId              = $TenantId
                    CertificateThumbprint = $CertificateThumbprint
                    CertificatePassword   = $CertificatePassword
                    CertificatePath       = $CertificatePath
                }
                $Results = Get-TargetResource @Params
                $Results = Update-M365DSCExportAuthenticationResults -ConnectionMode $ConnectionMode `
                    -Results $Results
                $currentDSCBlock = Get-M365DSCExportContentForResource -ResourceName $ResourceName `
                    -ConnectionMode $ConnectionMode `
                    -ModulePath $PSScriptRoot `
                    -Results $Results `
                    -Credential $Credential
                $dscContent += $currentDSCBlock
                Save-M365DSCPartialExport -Content $currentDSCBlock `
                    -FileName $Global:PartialExportFileName
            }
            Write-Host $Global:M365DSCEmojiGreenCheckMark
            $i++
        }
        return $dscContent
    }
    catch
    {
        try
        {
            Write-Verbose -Message $_
            $tenantIdValue = ""
            if (-not [System.String]::IsNullOrEmpty($TenantId))
            {
                $tenantIdValue = $TenantId
            }
            elseif ($null -ne $Credential)
            {
                $tenantIdValue = $Credential.UserName.Split('@')[1]
            }
            Add-M365DSCEvent -Message $_ -EntryType 'Error' `
                -EventID 1 -Source $($MyInvocation.MyCommand.Source) `
                -TenantId $tenantIdValue
        }
        catch
        {
            Write-Verbose -Message $_
        }
        return ""
    }
}

Export-ModuleMember -Function *-TargetResource
