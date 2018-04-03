<#
    .SYNOPSIS Modifies a DSC Local configuration manager setting

    .LINK https://docs.microsoft.com/en-us/powershell/dsc/metaconfig

    .PARAMETER CimSession
        The cimsession object or computer name of the target computer to be modified.

    .PARAMETER OutputPath
        The output path for mof files to be stored.

    .PARAMETER ConfigurationModeFrequencyMins
        How often, in minutes, the current configuration is checked and applied. This property is ignored if the ConfigurationMode property is set to ApplyOnly. The default value is 15.

    .PARAMETER RebootNodeIfNeeded
        Specifies whether or not the LCM can reboot the target

    .PARAMETER ConfigurationMode
        Specifies how the LCM actually applies the configuration to the target nodes.

    .PARAMETER ActionAfterReboot
        Specifies what happens after a reboot during the application of a configuration. 

    .PARAMETER RefreshMode
        Specifies how the LCM gets configurations.

    .PARAMETER CertificateId
        The thumbprint of a certificate used to secure credentials passed in a configuration.

    .PARAMETER RefreshFrequencyMins
        The time interval, in minutes, at which the LCM checks a pull service to get updated configurations.

    .PARAMETER AllowModuleOverwrite
        Specifies if new configurations are allowed to overwrite old ones using Pull service.
    
    .PARAMETER DebugMode
        Specifies the debug mode for the target

    .PARAMETER StatusRetentionTimeInDays
        The number of days the LCM keeps the status of the current configuration.

    .PARAMETER DeleteMofWhenDone
        Specifies whether or not to cleanup the resulting meta.mof file

    .EXAMPLE This command will set the RebootNodeIfNeeded to 'True' on the target, 'localhost'
        Set-LcmSetting -CimSession localhost -RebootNodeIfNeeded $true
#>
Function Set-LcmSetting
{
    Param
    (
        [Parameter()]
        [psobject]
        $CimSession,
        
        [Parameter()]
        [int]
        $ConfigurationModeFrequencyMins,
        
        [Parameter()]
        [bool]
        $RebootNodeIfNeeded,
        
        [Parameter()]
        [ValidateSet('ApplyOnly','ApplyAndMonitor','ApplyAndAutoCorrect')]
        [string]
        $ConfigurationMode = 'ApplyAndAutoCorrect',
        
        [Parameter()]
        [ValidateSet('ContinueConfiguration','StopConfiguration')]
        [string]
        $ActionAfterReboot,
        
        [Parameter()]
        [ValidateSet('Disabled','Push','Pull')]
        [string]
        $RefreshMode,
        
        [Parameter()]
        [string]
        $CertificateId,
        
        [Parameter()]
        [guid]
        $ConfigurationId,
        
        [Parameter()]
        [int]
        $RefreshFrequencyMins,
        
        [Parameter()]
        [bool]
        $AllowModuleOverwrite,
        
        [Parameter()]
        [ValidateSet('None','ForceModuleImport','All')]
        [string]
        $DebugMode,
        
        [Parameter()]
        [int]
        $StatusRetentionTimeInDays,

        [Parameter()]        
        [string]
        $OutputPath = "$env:windir\Temp\MofStore",
        
        [Parameter()]
        [boolean]
        $DeleteMofWhenDone = $true
    )

    #Requires -RunAsAdministrator

    if($CimSession)
    {
        $currentLcmConfig = Get-DscLocalConfigurationManager -CimSession $CimSession -ErrorAction Stop
        $computerName = Get-ComputerName -CimSession $CimSession

    }
    else
    {
        $currentLcmConfig = Get-DscLocalConfigurationManager -ErrorAction Stop
        $computerName = $env:COMPUTERNAME
        $CimSession = $env:COMPUTERNAME
    }

    $null = Test-OutputPath -Path $OutputPath
    $pendingChanges = $PSBoundParameters.Keys.Where({$script:commonParameters -notcontains $_})

    foreach($key in $pendingChanges)
    {
        $currentLcmConfig.$key = $PSBoundParameters[$key]
    }

    $configurations = Initialize-SettingsBlock -Configuration $currentLcmConfig
            
    foreach($partial in $currentLcmConfig.PartialConfigurations)
    {
        $configurations += Initialize-PartialBlock -Configuration $partial
    }
        
    $null = Invoke-LcmConfig -ComputerName $computerName -Configuration $configurations -OutputPath $OutputPath
    Set-DscLocalConfigurationManager -CimSession $CimSession -Path $OutputPath -Force

    if($DeleteMofWhenDone)
    {
        Remove-Item $OutputPath\$computerName.meta.mof -Force -ErrorAction Ignore
    }
}

<#
    .SYNOPSIS Resets a DSC Local configuration manager to a blank state

    .LINK https://docs.microsoft.com/en-us/powershell/dsc/metaconfig
    
    .PARAMETER CimSession
        The cimsession object or computer name of the target computer to be modified.

    .PARAMETER OutputPath
        The output path for mof files to be stored.

    .PARAMETER DeleteMofWhenDone
        Specifies whether or not to cleanup the resulting meta.mof file

    .EXAMPLE This command will reset the lcm on the target, 'localhost'
        Reset-LcmConfiguration -CimSession localhost
#>
Function Reset-LcmConfiguration
{
    [CmdletBinding()]
    Param
    (
        [Parameter()]
        [psobject]
        $CimSession,

        [string]
        $OutputPath = "$env:windir\Temp\MofStore",

        [Parameter()]
        [boolean]
        $DeleteMofWhenDone = $true
    )

    #Requires -RunAsAdministrator
    
    $selectProperties = 'RebootNodeIfNeeded','ConfigurationMode','RefreshMode','ActionAfterReboot'
    
    if($CimSession)
    {
        $currentLcmConfig = Get-DscLocalConfigurationManager -CimSession $CimSession -ErrorAction Stop | Select-Object -Property $selectProperties
        $computerName = Get-ComputerName -CimSession $CimSession

    }
    else
    {
        $currentLcmConfig = Get-DscLocalConfigurationManager -ErrorAction Stop | Select-Object -Property $selectProperties
        $computerName = $env:COMPUTERNAME
        $CimSession = $env:COMPUTERNAME
    }

    $null = Test-OutputPath -Path $OutputPath
    $configurations = Initialize-SettingsBlock -Configuration $currentLcmConfig

    $null = Invoke-LcmConfig -ComputerName $computerName -Configuration $configurations -OutputPath $OutputPath
    Set-DscLocalConfigurationManager -CimSession $CimSession -Path $OutputPath -Force

    foreach($stage in @('Current','Previous','Pending'))
    {
        Remove-DscConfigurationDocument -CimSession $CimSession -Stage $stage -Force
    }

    if($DeleteMofWhenDone)
    {
        Remove-Item $OutputPath\$computerName.meta.mof -Force -ErrorAction Ignore
    }
}

<#
    .SYNOPSIS Removes a partial configuration by name from a target local configuration manager

    .LINK https://docs.microsoft.com/en-us/powershell/dsc/metaconfig
    
    .PARAMETER CimSession
        The cimsession object or computer name of the target computer to be modified.

    .PARAMETER OutputPath
        The output path for mof files to be stored.

    .PARAMETER ConfigurationSource
        An array of names of configuration servers, previously defined in ConfigurationRepositoryWeb and ConfigurationRepositoryShare blocks, where the partial configuration is pulled from.
    
    .PARAMETER Description
        Text used to describe the partial configuration.
            
    .PARAMETER ExclusiveResources
        An array of resources exclusive to this partial configuration.

    .PARAMETER RefreshMode
        Specifies what happens after a reboot during the application of a configuration. 

    .PARAMETER ResourceModuleSource
        An array of the names of resource servers from which to download required resources for this partial configuration         

    .PARAMETER DeleteMofWhenDone
        Specifies whether or not to cleanup the resulting meta.mof file

    .EXAMPLE This command will remove the partial configuration 'test partial' on the target, 'localhost'
        Remove-LcmPartialConfiguration -CimSession localhost -PartialName 'test partial'
#>
Function Remove-LcmPartialConfiguration
{
    [CmdletBinding()]
    Param
    (    
        [Parameter()]
        [psobject]
        $CimSession,
        
        [Parameter(Mandatory = $true)]
        [string]
        $PartialName,

        [Parameter()]
        [string]
        $OutputPath = "$env:windir\Temp\MofStore",

        [Parameter()]
        [boolean]
        $DeleteMofWhenDone = $true
    )

    #Requires -RunAsAdministrator

    if($CimSession)
    {
        $currentLcmConfig = Get-DscLocalConfigurationManager -CimSession $CimSession -ErrorAction Stop
        $computerName = Get-ComputerName -CimSession $CimSession

    }
    else
    {
        $currentLcmConfig = Get-DscLocalConfigurationManager -ErrorAction Stop
        $computerName = $env:COMPUTERNAME
        $CimSession = $env:COMPUTERNAME
    }
    
    $null = Test-OutputPath -Path $OutputPath
    $partialConfiguration = $currentLcmConfig.PartialConfigurations.Where({$($_.ResourceId.Replace('[PartialConfiguration]','')) -eq $PartialName})

    if(-not $partialConfiguration)
    {
        throw "Invalid partial name, $PartialName."
    }

    $configurations = Initialize-SettingsBlock -Configuration $currentLcmConfig
            
    foreach($partial in $currentLcmConfig.PartialConfigurations)
    {
        if($partial.ResourceId.Replace('[PartialConfiguration]','') -ne $PartialName)
        {
            if($partial.DependsOn -contains "[PartialConfiguration]$PartialName")
            {
                $partial.DependsOn = $partial.DependsOn.Where({$_ -ne "[PartialConfiguration]$PartialName"})
            }

            $configurations += Initialize-PartialBlock -Configuration $partial
        }
    }

    $null = Invoke-LcmConfig -ComputerName $computerName -Configuration $configurations -OutputPath $OutputPath
    Set-DscLocalConfigurationManager -CimSession $CimSession -Path $OutputPath -Force

    if($DeleteMofWhenDone)
    {
        Remove-Item $OutputPath\$computerName.meta.mof -Force -ErrorAction Ignore
    }
}

<#
    .SYNOPSIS Adds a partial configuration by name from a target local configuration manager

    .LINK https://docs.microsoft.com/en-us/powershell/dsc/metaconfig
    
    .PARAMETER CimSession
        The cimsession object or computer name of the target computer to be modified.

    .PARAMETER OutputPath
        The output path for mof files to be stored.

    .PARAMETER PartialName
        The name of the partial configuration to add to the target

    .PARAMETER ConfigurationSource
        An array of names of configuration servers, previously defined in ConfigurationRepositoryWeb and ConfigurationRepositoryShare blocks, where the partial configuration is pulled from.
    
    .PARAMETER Description
        Text used to describe the partial configuration.
            
    .PARAMETER ExclusiveResources
        An array of resources exclusive to this partial configuration.

    .PARAMETER RefreshMode
        Specifies how the LCM gets configurations. The possible values are "Disabled", "Push", and "Pull".

    .PARAMETER ResourceModuleSource
        An array of the names of resource servers from which to download required resources for this partial configuration         

    .PARAMETER DeleteMofWhenDone
        Specifies whether or not to cleanup the resulting meta.mof file

    .EXAMPLE This command will add the partial configuration 'test partial' on the target, 'localhost'
        Add-LcmPartialConfiguration -CimSession localhost -PartialName 'test partial'
#>
Function Add-LcmPartialConfiguration
{
    [CmdletBinding()]
    Param
    (    
        [Parameter()]
        [psobject]
        $CimSession,
        
        [Parameter(Mandatory = $true)]
        [string]
        $PartialName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Disabled','Push','Pull')]
        [string]
        $RefreshMode,
        
        [Parameter()]
        [string[]]
        $ConfigurationSource,
        
        [Parameter()]
        [System.Collections.Generic.List[string]]
        $DependsOn,
        
        [Parameter()]
        [string]
        $Description,
        
        [Parameter()]
        [string[]]
        $ExclusiveResources,
        
        [Parameter()]
        [string[]]
        $ResourceModuleSource,

        [Parameter()]
        [string]
        $OutputPath = "$env:windir\Temp\MofStore",

        [Parameter()]
        [boolean]
        $DeleteMofWhenDone = $true
    )
    
    #Requires -RunAsAdministrator

    if($CimSession)
    {
        $currentLcmConfig = Get-DscLocalConfigurationManager -CimSession $CimSession -ErrorAction Stop
        $computerName = Get-ComputerName -CimSession $CimSession

    }
    else
    {
        $currentLcmConfig = Get-DscLocalConfigurationManager -ErrorAction Stop
        $computerName = $env:COMPUTERNAME
        $CimSession = $env:COMPUTERNAME
    }
    
    $null = Test-OutputPath -Path $OutputPath
    $existingPartials = $currentLcmConfig.PartialConfigurations.ResourceId
        
    if($existingPartials -and $existingPartials.Replace('[PartialConfiguration]','') -contains $PartialName)
    {
        $partialExists = $true
        Write-Warning "Partial configuration $PartialName already exists on computer $ComputerName"
    }
        
    $pendingChanges = $PSBoundParameters.Keys.Where({$script:commonParameters -notcontains $_})

    $hashChanges = @{}
    foreach($pendingChange in $pendingChanges)
    {
        if($pendingChange -eq 'PartialName')
        {
            $hashChanges.Add("ResourceId", "[PartialConfiguration]$($PSBoundParameters[$pendingChange])")
        }
        elseif($pendingChange -eq 'DependsOn')
        {
            $hashChanges.Add($pendingChange, "[PartialConfiguration]$($PSBoundParameters[$pendingChange])")
        }
        else
        {
            $hashChanges.Add($pendingChange, $PSBoundParameters[$pendingChange])
        }
    }

    $configurations = Initialize-SettingsBlock -Configuration $currentLcmConfig
            
    foreach($partial in $currentLcmConfig.PartialConfigurations)
    {
        $configurations += Initialize-PartialBlock -Configuration $partial
    }

    if(-not $partialExists)
    {
        $configurations += Initialize-PartialBlock -Configuration $(New-Object -TypeName PsObject -Property $hashChanges)
    }

    $null = Invoke-LcmConfig -ComputerName $computerName -Configuration $configurations -OutputPath $OutputPath
    Set-DscLocalConfigurationManager -CimSession $CimSession -Path $OutputPath -Force

    if($DeleteMofWhenDone)
    {
        Remove-Item $OutputPath\$computerName.meta.mof -Force -ErrorAction Ignore
    }
}

<#
    .SYNOPSIS Modifies a DSC Local configuration manager setting

    .LINK https://docs.microsoft.com/en-us/powershell/dsc/metaconfig

    .PARAMETER CimSession
        The cimsession object or computer name of the target computer to be modified.

    .PARAMETER OutputPath
        The output path for mof files to be stored.

    .PARAMETER PartialName
        The name of the partial configuration to modify on the target.

    .PARAMETER ConfigurationSource
        An array of names of configuration servers, previously defined in ConfigurationRepositoryWeb and ConfigurationRepositoryShare blocks, where the partial configuration is pulled from.
    
    .PARAMETER Description
        Text used to describe the partial configuration.
            
    .PARAMETER ExclusiveResources
        An array of resources exclusive to this partial configuration.

    .PARAMETER RefreshMode
        Specifies how the LCM gets configurations. The possible values are "Disabled", "Push", and "Pull".

    .PARAMETER ResourceModuleSource
        An array of the names of resource servers from which to download required resources for this partial configuration         

    .PARAMETER DeleteMofWhenDone
        Specifies whether or not to cleanup the resulting meta.mof file

    .EXAMPLE This command will set the Description to 'Test partial description' on the partial, 'Test partial' on the target, 'localhost'
        Set-LcmPartialConfiguration -CimSession localhost -PartialName 'Test partial' -Description 'Test partial description'

#>
Function Set-LcmPartialConfiguration
{
    Param
    (
        [Parameter()]
        [psobject]
        $CimSession,

        [Parameter()]
        [string]
        $PartialName,

        [Parameter()]
        [string[]]
        $ConfigurationSource,
        
        [Parameter()]
        [System.Collections.Generic.List[string]]
        $DependsOn,
        
        [Parameter()]
        [string]
        $Description,
        
        [Parameter()]
        [string[]]
        $ExclusiveResources,
        
        [Parameter()]
        [ValidateSet('Disabled','Push','Pull')]
        [string]
        $RefreshMode,
        
        [Parameter()]
        [string[]]
        $ResourceModuleSource,

        [Parameter()]
        [string]
        $OutputPath = "$env:windir\Temp\MofStore",

        [Parameter()]
        [boolean]
        $DeleteMofWhenDone = $true
    )

    #Requires -RunAsAdministrator

    if($CimSession)
    {
        $currentLcmConfig = Get-DscLocalConfigurationManager -CimSession $CimSession -ErrorAction Stop
        $computerName = Get-ComputerName -CimSession $CimSession

    }
    else
    {
        $currentLcmConfig = Get-DscLocalConfigurationManager -ErrorAction Stop
        $computerName = $env:COMPUTERNAME
        $CimSession = $env:COMPUTERNAME
    }
    
    $null = Test-OutputPath -Path $OutputPath
    $partialConfiguration = $currentLcmConfig.PartialConfigurations.Where({$($_.ResourceId.Replace('[PartialConfiguration]','')) -eq $PartialName})

    if(-not $partialConfiguration)
    {
        throw "Invalid partial name, $PartialName."
    }
        
    $pendingChanges = $PSBoundParameters.Keys.Where({$script:commonParameters -notcontains $_})
    $configurations = Initialize-SettingsBlock -Configuration $currentLcmConfig
    foreach($partial in $currentLcmConfig.PartialConfigurations)
    {
        if($partial.ResourceId -eq $partialConfiguration.ResourceId)
        {
            $hashChanges = @{}
            foreach($pendingChange in $pendingChanges)
            {
                if($pendingChange -eq 'PartialName')
                {
                    $hashChanges.Add("ResourceId", "[PartialConfiguration]$($PSBoundParameters[$pendingChange])")
                }
                elseif($pendingChange -eq 'DependsOn')
                {
                    $hashChanges.Add($pendingChange, "[PartialConfiguration]$($PSBoundParameters[$pendingChange])")
                }
                else
                {
                    $hashChanges.Add($pendingChange, $PSBoundParameters[$pendingChange])
                }
            }

            $unmodifiedProperties = ($partial | Get-Member -MemberType Property).Name | Where-Object {$hashChanges.Keys -notcontains $_}
            foreach($existingProperty in $unmodifiedProperties)
            {
                if($partial.$existingProperty)
                {
                    $hashChanges.Add($existingProperty, $partial.$existingProperty)
                }
            }
            
            $configurations += Initialize-PartialBlock -Configuration $(New-Object -TypeName PsObject -Property $hashChanges)
        }
        else
        {
            $configurations += Initialize-PartialBlock -Configuration $partial
        }
    }
        
    $null = Invoke-LcmConfig -ComputerName $ComputerName -Configuration $configurations -OutputPath $OutputPath
    Set-DscLocalConfigurationManager -CimSession $CimSession -Path $OutputPath -Force

    if($DeleteMofWhenDone)
    {
        Remove-Item $OutputPath\$computerName.meta.mof -Force -ErrorAction Ignore
    }
}

Function Invoke-LcmConfig
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $ComputerName,

        [Parameter(Mandatory = $true)]
        [string]
        $Configuration,

        [Parameter(Mandatory = $true)]
        [string]
        $OutputPath
    )

    [DSCLocalConfigurationManager()]
    Configuration LcmConfig
    {
        Node $ComputerName
        {
            Invoke-Command -ScriptBlock $ExecutionContext.InvokeCommand.NewScriptBlock($Configuration)
        }
    }

    LcmConfig -OutputPath $OutputPath
}

Function Get-ComputerName
{
    Param
    (
        [Parameter(Mandatory = $true)]
        [psobject]
        $CimSession
    )

    if($CimSession -is [Microsoft.Management.Infrastructure.CimSession])
    {
        return $CimSession.ComputerName
    }
    else
    {
        return $CimSession
    }
}

Function Test-OutputPath
{
    Param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )

    if(-not (Test-Path $OutputPath))
    {
        New-Item -Path $OutputPath -ItemType Directory
    }
}

Function Initialize-PartialBlock
{
    Param
    (
        [Parameter()]
        [psobject]
        $Configuration
    )

    $PartialConfigurationParameters = @(
        'ConfigurationSource',
        'DependsOn',
        'Description',
        'ExclusiveResources',
        'RefreshMode',
        'ResourceModuleSource'
    )

    $output += "PartialConfiguration $($Configuration.ResourceId.Split("]")[1])`n"
    $output += "{`n"
        
    foreach($partialProperty in $PartialConfigurationParameters)
    {
        if($($Configuration.$partialProperty))
        {
            $output += "    $partialProperty = '$($Configuration.$partialProperty -join "','")'`n"
        }
    }
    
    $output += "}`n"

    return $output
}

Function Initialize-SettingsBlock
{
    Param
    (
        [Parameter(Mandatory = $true)]
        [psobject]$Configuration
    )

    $LcmSettingParameters = @(
        'ConfigurationModeFrequencyMins',
        'RebootNodeIfNeeded',
        'ConfigurationMode',
        'ActionAfterReboot',
        'RefreshMode',
        'CertificateId',
        'ConfigurationId',
        'RefreshFrequencyMins',
        'AllowModuleOverwrite',
        'DebugMode',
        'StatusRetentionTimeInDays'
    )
    
    $output = "Settings`n"
    $output += "{`n"

    foreach($property in $LcmSettingParameters)
    {
        if($($Configuration.$property) -eq $true -or $($Configuration.$property) -eq $false)
        {
            $output += "    $property = $" + "$($Configuration.$property)`n"
        }
        elseif($Configuration.$property)
        {
            $output += "    $property = '$($Configuration.$property)'`n"
        }
    }
    
    $output += "}`n"
    
    return $output
}

$script:commonParameters = [System.Management.Automation.Cmdlet]::CommonParameters + [System.Management.Automation.Cmdlet]::OptionalCommonParameters
$script:commonParameters += 'CimSession', 'OutputPath','DeleteMofWhenDone'

Export-ModuleMember -Function @(
    'Set-LcmSetting',
    'Reset-LcmConfiguration',
    'Remove-LcmPartialConfiguration',
    'Add-LcmPartialConfiguration',
    'Set-LcmPartialConfiguration'
)
