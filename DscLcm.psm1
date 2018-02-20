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
function Set-LcmSetting
{
    param
    (
        [Parameter(Mandatory = $true)]
        [psobject]$CimSession,
                
        [string]$OutputPath = "$env:windir\Temp\MofStore",

        [int]$ConfigurationModeFrequencyMins,
        
        [bool]$RebootNodeIfNeeded,
        
        [ValidateSet('ApplyOnly','ApplyAndMonitor','ApplyAndAutoCorrect')]
        [string]$ConfigurationMode = 'ApplyAndAutoCorrect',
        
        [ValidateSet('ContinueConfiguration','StopConfiguration')]
        [string]$ActionAfterReboot,
        
        [ValidateSet('Disabled','Push','Pull')]
        [string]$RefreshMode = 'Push',
        
        [string]$CertificateId,
        
        [guid]$ConfigurationId,
        
        [int]$RefreshFrequencyMins,
        
        [bool]$AllowModuleOverwrite,
        
        [ValidateSet('None','ForceModuleImport','All')]
        [string]$DebugMode,
        
        [int]$StatusRetentionTimeInDays,
        
        [switch]$DeleteMofWhenDone        
    )

    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
    $commonParameters = Get-CommonParameterName
    $computerName = Get-ComputerName -CimSession $CimSession

    try
    {
        Test-OutputPath -Path $OutputPath
        $currentLcmConfig = Get-DscLocalConfigurationManager -CimSession $CimSession | Select-Object -ExcludeProperty DebugMode
        $pendingChanges = $PSBoundParameters.Keys.Where({$commonParameters -notcontains $_})

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
    }
    finally
    {
        if($DeleteMofWhenDone)
        {
            Remove-Item $OutputPath\$computerName.meta.mof -Force -ErrorAction Ignore
        }

        $ErrorActionPreference = $oldEap
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
function Reset-LcmConfiguration
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [psobject]$CimSession,

        [string]$OutputPath = "$env:windir\Temp\MofStore",

        [switch]$DeleteMofWhenDone
    )

    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
    $computerName = Get-ComputerName -CimSession $CimSession
    
    try
    {
        Test-OutputPath -Path $OutputPath
        $currentLcmConfig = Get-DscLocalConfigurationManager -CimSession $CimSession | Select-Object -Property RebootNodeIfNeeded,ConfigurationMode,RefreshMode,ActionAfterReboot
        $configurations = Initialize-SettingsBlock -Configuration $currentLcmConfig

        Invoke-LcmConfig -ComputerName $computerName -Configuration $configurations -OutputPath $OutputPath
        Set-DscLocalConfigurationManager -CimSession $CimSession -Path $OutputPath -Force

        foreach($stage in @('Current','Previous','Pending'))
        {
            Remove-DscConfigurationDocument -CimSession $CimSession -Stage $stage -Force
        }
    }
    finally
    {        
        if($DeleteMofWhenDone)
        {
            Remove-Item $OutputPath\$computerName.meta.mof -Force -ErrorAction Ignore
        }

        $ErrorActionPreference = $oldEap
    }
}


<#
    .SYNOPSIS Removes a partial configuration by name from a target local configuration manager

    .LINK https://docs.microsoft.com/en-us/powershell/dsc/metaconfig
    
    .PARAMETER CimSession
        The cimsession object or computer name of the target computer to be modified.

    .PARAMETER OutputPath
        The output path for mof files to be stored.

    .PARAMETER PartialName
        The name of the partial configuration to remove from the target

    .PARAMETER DeleteMofWhenDone
        Specifies whether or not to cleanup the resulting meta.mof file

    .EXAMPLE This command will remove the partial configuration 'test partial' on the target, 'localhost'
        Remove-LcmPartialConfiguration -CimSession localhost -PartialName 'test partial'
#>
function Remove-LcmPartialConfiguration
{
    [CmdletBinding()]
    param
    (    
        [Parameter(Mandatory = $true)]
        [psobject]$CimSession,
        
        [Parameter(Mandatory = $true)]
        [string]$PartialName,

        [string]$OutputPath = "$env:windir\Temp\MofStore",

        [switch]$DeleteMofWhenDone        
    )
    
    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
    $computerName = Get-ComputerName -CimSession $CimSession

    try
    {
        Test-OutputPath -Path $OutputPath
        $currentLcmConfig = Get-DscLocalConfigurationManager -CimSession $CimSession | Select-Object -ExcludeProperty DebugMode       
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
    }
    finally
    {
        if($DeleteMofWhenDone)
        {
            Remove-Item $OutputPath\$computerName.meta.mof -Force -ErrorAction Ignore
        }

        $ErrorActionPreference = $oldEap
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

    .PARAMETER DeleteMofWhenDone
        Specifies whether or not to cleanup the resulting meta.mof file

    .EXAMPLE This command will add the partial configuration 'test partial' on the target, 'localhost'
        Add-LcmPartialConfiguration -CimSession localhost -PartialName 'test partial'
#>
function Add-LcmPartialConfiguration
{
    [CmdletBinding()]
    param
    (    
        [Parameter(Mandatory = $true)]
        [psobject]$CimSession,
        
        [Parameter(Mandatory = $true)]
        [string]$PartialName,

        [ValidateSet('Disabled','Push','Pull')]
        [string]$RefreshMode = 'Push',

        [string]$OutputPath = "$env:windir\Temp\MofStore",
        
        [string[]]$ConfigurationSource,
        
        [System.Collections.Generic.List[string]]$DependsOn,
        
        [string]$Description,
        
        [string[]]$ExclusiveResources,
             
        [string[]]$ResourceModuleSource,

        [switch]$DeleteMofWhenDone        
    )
    
    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
    $commonParameters = Get-CommonParameterName
    $computerName = Get-ComputerName -CimSession $CimSession

    try
    {        
        Test-OutputPath -Path $OutputPath
        $currentLcmConfig = Get-DscLocalConfigurationManager -CimSession $CimSession | Select-Object -ExcludeProperty DebugMode
        $existingPartials = $currentLcmConfig.PartialConfigurations.ResourceId
        
        if($existingPartials -and $existingPartials.Replace('[PartialConfiguration]','') -contains $PartialName)
        {
            $partialExists = $true
            Write-Warning "Partial configuration $PartialName already exists on computer $ComputerName"
        }
        
        $pendingChanges = $PSBoundParameters.Keys.Where({$commonParameters -notcontains $_})

        $hashChanges = @{}
        foreach($pendingChange in $pendingChanges)
        {
            if($pendingChange -eq 'PartialName')
            {
                $hashChanges.Add("ResourceId", "[PartialConfiguration]$($PSBoundParameters[$pendingChange])")
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
    }
    finally
    {     
        if($DeleteMofWhenDone)
        {
            Remove-Item $OutputPath\$computerName.meta.mof -Force -ErrorAction Ignore
        }
       
        $ErrorActionPreference = $oldEap
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
        Specifies what happens after a reboot during the application of a configuration. 

    .PARAMETER ResourceModuleSource
        An array of the names of resource servers from which to download required resources for this partial configuration         

    .PARAMETER DeleteMofWhenDone
        Specifies whether or not to cleanup the resulting meta.mof file

    .EXAMPLE This command will set the Description to 'Test partial description' on the partial, 'Test partial' on the target, 'localhost'
        Set-LcmPartialConfiguration -CimSession localhost -PartialName 'Test partial' -Description 'Test partial description'

#>
function Set-LcmPartialConfiguration
{
    param
    (
        [Parameter(Mandatory = $true)]
        [psobject]$CimSession,

        [string]$OutputPath = "$env:windir\Temp\MofStore",

        [string]$PartialName,

        [string[]]$ConfigurationSource,
        
        [System.Collections.Generic.List[string]]$DependsOn,
        
        [string]$Description,
        
        [string[]]$ExclusiveResources,
        
        [ValidateSet('Disabled','Push','Pull')]
        [string]$RefreshMode,
                
        [string[]]$ResourceModuleSource,

        [switch]$DeleteMofWhenDone        
    )

    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
    $commonParameters = Get-CommonParameterName
    $computerName = Get-ComputerName -CimSession $CimSession

    try
    {
        Test-OutputPath -Path $OutputPath
        $currentLcmConfig = Get-DscLocalConfigurationManager -CimSession $CimSession | Select-Object -ExcludeProperty DebugMode
        $partialConfiguration = $currentLcmConfig.PartialConfigurations.Where({$($_.ResourceId.Replace('[PartialConfiguration]','')) -eq $PartialName})

        if(-not $partialConfiguration)
        {
            throw "Invalid partial name, $PartialName."
        }
        
        $pendingChanges = $PSBoundParameters.Keys.Where({$commonParameters -notcontains $_})
        $configurations = Initialize-SettingsBlock -Configuration $currentLcmConfig
        
        foreach($partial in $currentLcmConfig.PartialConfigurations)
        {
            if($partial.ResourceId -eq $partialConfiguration.ResourceId)
            {
                foreach($key in $pendingChanges)
                {
                    $partial.$key = $PSBoundParameters[$key]
                }
            }

            $configurations += Initialize-PartialBlock -Configuration $partial
        }

        $null = Invoke-LcmConfig -ComputerName $ComputerName -Configuration $configurations -OutputPath $OutputPath
        Set-DscLocalConfigurationManager -CimSession $CimSession -Path $OutputPath -Force
    }
    finally
    {          
        if($DeleteMofWhenDone)
        {
            Remove-Item $OutputPath\$computerName.meta.mof -Force -ErrorAction Ignore
        }
  
        $ErrorActionPreference = $oldEap
    }
}

function Invoke-LcmConfig
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,

        [Parameter(Mandatory = $true)]
        [string]$Configuration,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    [DSCLocalConfigurationManager()]
    configuration LcmConfig
    {
        Node $ComputerName
        {
            Invoke-Command -ScriptBlock $ExecutionContext.InvokeCommand.NewScriptBlock($Configuration)
        }
    }

    LcmConfig -OutputPath $OutputPath
}

function Get-CommonParameterName
{
    [CmdletBinding()]
    param
    (
        $CimSession
    )

    (Get-Command Get-CommonParameterName).Parameters.Keys
}

function Get-ComputerName
{
    param
    (
        [Parameter(Mandatory = $true)]
        [psobject]$CimSession
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

function Test-OutputPath
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if(-not (Test-Path $OutputPath))
    {
        $null = New-Item -Path $OutputPath -ItemType Directory
    }
}

function Initialize-PartialBlock
{
    param
    (
        [psobject]$Configuration
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

function Initialize-SettingsBlock
{
    param
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

Export-ModuleMember -Function @(
    'Set-LcmSetting',
    'Reset-LcmConfiguration',
    'Remove-LcmPartialConfiguration',
    'Add-LcmPartialConfiguration'
    'Set-LcmPartialConfiguration'
)
