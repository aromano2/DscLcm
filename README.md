# DscLcm

The **DscLcm** module allows you to alter the LCM settings individually.

## Description

The **DscLcm** module comes with the following functions to manage the LCM: **Set-LcmSetting**, **Add-LcmPartialConfiguration**, **Remove-LcmPartialConfiguration**, **Set-LcmPartialConfiguration** and **Reset-LcmConfiguration**. These functions give you greater control over the LCM and the partial configurations applied to it.

## Functions
**Set-LcmSetting** Modifies settings in the LCM Settings Configuration block
**Add-LcmPartialConfiguration** Adds a new partial configuration to an LCM
**Remove-LcmPartialConfiguration** Removes a partial configuration from an LCM
**Set-LcmPartialConfiguration** Modifies a setting on an existing partial configuration in the LCM
**Reset-LcmConfiguration** Resets the LCM's settings to a default state

### **Set-LcmSetting**

* **CimSession** The cimsession object or computer name of the target computer to be modified.

* **OutputPath** The output path for mof files to be stored.

* **ConfigurationModeFrequencyMins** How often, in minutes, the current configuration is checked and applied. This property is ignored if the ConfigurationMode property is set to ApplyOnly. The default value is 15.

* **RebootNodeIfNeeded** Specifies whether or not the LCM can reboot the target

* **ConfigurationMode** Specifies how the LCM actually applies the configuration to the target nodes.

* **ActionAfterReboot** Specifies what happens after a reboot during the application of a configuration. 

* **RefreshMode** Specifies how the LCM gets configurations.

* **CertificateId** The thumbprint of a certificate used to secure credentials passed in a configuration.

* **RefreshFrequencyMins** The time interval, in minutes, at which the LCM checks a pull service to get updated configurations.

* **AllowModuleOverwrite** Specifies if new configurations are allowed to overwrite old ones using Pull service.
    
* **DebugMode** Specifies the debug mode for the target

* **StatusRetentionTimeInDays** The number of days the LCM keeps the status of the current configuration.

* **DeleteMofWhenDone** Specifies whether or not to cleanup the resulting meta.mof file

####Example
* This command will set the RebootNodeIfNeeded to 'True' on the target, 'localhost'
        Set-LcmSetting -CimSession localhost -RebootNodeIfNeeded $true

### **Add-LcmPartialConfiguration**

* **CimSession** The cimsession object or computer name of the target computer to be modified.

* **OutputPath** The output path for mof files to be stored.

* **PartialName** The name of the partial configuration to remove from the target

* **RefreshMode** Specifies how the LCM gets configurations. The possible values are "Disabled", "Push", and "Pull"

* **ConfigurationSource** An array of names of configuration servers, previously defined in ConfigurationRepositoryWeb and ConfigurationRepositoryShare blocks, where the partial configuration is pulled from.

* **Description** Text used to describe the partial configuration.

* **ExclusiveResources** An array of resources exclusive to this partial configuration.

* **ResourceModuleSource** An array of the names of resource servers from which to download required resources for this partial configuration         

* **DeleteMofWhenDone** Specifies whether or not to cleanup the resulting meta.mof file

### **Remove-LcmPartialConfiguration**

* **CimSession** The cimsession object or computer name of the target computer to be modified.

* **PartialName** The name of the partial configuration to remove from the target

* **OutputPath** The output path for mof files to be stored.

* **DeleteMofWhenDone** Specifies whether or not to cleanup the resulting meta.mof file

### **Set-LcmPartialConfiguration**

* **CimSession** The cimsession object or computer name of the target computer to be modified.

* **OutputPath** The output path for mof files to be stored.

* **PartialName** The name of the partial configuration to remove from the target

* **RefreshMode** Specifies how the LCM gets configurations. The possible values are "Disabled", "Push", and "Pull"

* **ConfigurationSource** An array of names of configuration servers, previously defined in ConfigurationRepositoryWeb and ConfigurationRepositoryShare blocks, where the partial configuration is pulled from.

* **Description** Text used to describe the partial configuration.

* **ExclusiveResources** An array of resources exclusive to this partial configuration.

* **ResourceModuleSource** An array of the names of resource servers from which to download required resources for this partial configuration         

* **DeleteMofWhenDone** Specifies whether or not to cleanup the resulting meta.mof file

### **Reset-LcmConfiguration**

* **CimSession** The cimsession object or computer name of the target computer to be modified.

* **PartialName** The name of the partial configuration to remove from the target

* **OutputPath** The output path for mof files to be stored.

* **DeleteMofWhenDone** Specifies whether or not to cleanup the resulting meta.mof file


### 1.0
* Initial release with the following functions:
    * Set-LcmSetting, Add-LcmPartialConfiguration, Remove-LcmPartialConfiguration, Set-LcmPartialConfiguration, Reset-LcmConfiguration

### 1.1
* Bug fix for Set-LcmPartialConfiguration
* Help file cleanup
* Readme updated