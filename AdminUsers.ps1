$csvPath = "C:\Temp\ADminUsers1.csv"
$domain = "ECE"
$RDPGRPSID=(Get-MgGroup -Filter "displayName eq 'UG_WIN_IN_RDPUsers'").SecurityIdentifier

# Graph verbinden
#Connect-MgGraph -Scopes Device.Read.All, Group.ReadWrite.All, DeviceManagementConfiguration.ReadWrite.All, Directory.Read.All

# CSV einlesen
$entries = Import-Csv -Path $csvPath -Delimiter ";"

foreach ($entry in $entries) {
    $user = $entry.SAMAccountName
    $computer = $entry.ComputerName
    $groupName = "DG_WIN_IN_ADM-$computer"
    $device = ""
    $groups = ""
    $deviceId = ""
    $groupId = ""
    $exGroupID = ""
    $exGroupMembers= ""
    $policys = ""
    $policyBody = ""
    $policy = ""
    $policyId = ""
    $assignmentBody = ""


    # Gruppe erstellen
    $groupBody = @{
        displayName     = $groupName
        mailEnabled     = $false
        mailNickname    = $groupName.Replace("-", "_").ToLower()
        securityEnabled = $true
        groupTypes      = @()
    }


    # Gerät suchen
    $device = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/devices?`$filter=displayName eq '$computer'" -ErrorAction SilentlyContinue
    if ($device.value.Count -eq 0) {
        Write-Warning "Gerät '$computer' nicht gefunden."
        continue #Nächster Wert, falls es das Gerät nicht gibt.
    }
    $groups = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups").value.displayName
    If ($groupName -in $groups){
        Write-Host "Group $groupName already Exists!"
    }
    Else {
        $group = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/groups" -Body (ConvertTo-Json $groupBody -Depth 3)
        $groupId = $group.id
        Write-Host "Gruppe erstellt: $groupName ($groupId)"

        $deviceId = $device.value[0].id

        # Gerät zur Gruppe hinzufügen
        $addMemberBody = @{
            "@odata.id" = "https://graph.microsoft.com/v1.0/devices/$deviceId"
        }
        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/groups/$groupId/members/`$ref" -Body (ConvertTo-Json $addMemberBody)
        Write-Host "Gerät hinzugefügt: $deviceId"

        #Gerät zu weiterer Gruppe hinzufügen
        $exGroupID = (Get-MgGroup -Filter "displayName eq 'DG_WIN_IN_ADM-DevicesWithLocalAdmin'").id
        $exGroupMembers= Get-MgGroupMember -GroupId $exGroupID
        If ($exGroupMembers -notcontains $deviceId) {
            $addExMemberBody = @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/devices/$deviceId"
            }
            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/groups/$exGroupID/members/`$ref" -Body (ConvertTo-Json $addExMemberBody)
            Write-Host "Gerät hinzugefügt: $deviceId"
        }
        Else {
            Write-Host "Gerät ist bereits in der Gruppe $exGroupID."
        }   
    }

    # Endpoint Security Account Protection Policy erstellen

    $policys = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies").values.name
        If ("WIN_AP_ADM-$computer" -in $policys){
            Write-Host "Group $groupName already Exists!"
            continue #Nächster Wert, falls es die Policy schon gibt
        }

    $policyBody =@{
    "@odata.context"= "https://graph.microsoft.com/beta/$metadata#deviceManagement/configurationPolicies/$entity"
    description= "Policy to set $user as local Administrator on $computer."
    name= "WIN_AP_ADM-$computer"
    platforms= "windows10"
    priorityMetaData= $null
    roleScopeTagIds= @("0")
    settingCount= 1
    technologies= "mdm"
    templateReference= @{
        templateId= "22968f54-45fa-486c-848e-f8224aa69772_1"
        templateFamily= "endpointSecurityAccountProtection"
        templateDisplayName= "Local user group membership"
        templateDisplayVersion= "Version 1"
    }
    settings= @(@{
            id= "0"
            settingInstance= @{
                "@odata.type"= "#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance"
                settingDefinitionId= "device_vendor_msft_policy_config_localusersandgroups_configure"
                settingInstanceTemplateReference= @{
                    settingInstanceTemplateId= "de06bec1-4852-48a0-9799-cf7b85992d45"
                }
                groupSettingCollectionValue= @(
                @{
                    settingValueTemplateReference= $null
                    children= @(@{
                        "@odata.type"= "#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance"
                        settingDefinitionId= "device_vendor_msft_policy_config_localusersandgroups_configure_groupconfiguration_accessgroup"
                        settingInstanceTemplateReference= $null
                        groupSettingCollectionValue= @(@{
                            settingValueTemplateReference= $null
                            children= @(@{
                                "@odata.type"= "#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance"
                                settingDefinitionId= "device_vendor_msft_policy_config_localusersandgroups_configure_groupconfiguration_accessgroup_desc"
                                settingInstanceTemplateReference= $null
                                choiceSettingCollectionValue= @(@{
                                    settingValueTemplateReference= $null
                                    value= "device_vendor_msft_policy_config_localusersandgroups_configure_groupconfiguration_accessgroup_desc_administrators"
                                    children= @()
                                })
                                }
                                @{
                                "@odata.type"= "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance"
                                settingDefinitionId= "device_vendor_msft_policy_config_localusersandgroups_configure_groupconfiguration_accessgroup_action"
                                settingInstanceTemplateReference= $null
                                choiceSettingValue= @{
                                    settingValueTemplateReference= $null
                                    value= "device_vendor_msft_policy_config_localusersandgroups_configure_groupconfiguration_accessgroup_action_add_update"
                                    children= @()
                                }
                                }
                                @{
                                "@odata.type"= "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance"
                                settingDefinitionId= "device_vendor_msft_policy_config_localusersandgroups_configure_groupconfiguration_accessgroup_userselectiontype"
                                settingInstanceTemplateReference= $null
                                choiceSettingValue= @{
                                    settingValueTemplateReference= $null
                                    value= "device_vendor_msft_policy_config_localusersandgroups_configure_groupconfiguration_accessgroup_userselectiontype_manual"
                                    children= @(@{
                                        "@odata.type"= "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance"
                                        settingDefinitionId= "device_vendor_msft_policy_config_localusersandgroups_configure_groupconfiguration_accessgroup_users"
                                        settingInstanceTemplateReference= $null
                                        simpleSettingCollectionValue= @(@{
                                            "@odata.type"= "#microsoft.graph.deviceManagementConfigurationStringSettingValue"
                                            settingValueTemplateReference= $null
                                            value= "$domain\GPO-Win10-Client-Admin-Support"
                                            }
                                            @{
                                            "@odata.type"= "#microsoft.graph.deviceManagementConfigurationStringSettingValue"
                                            settingValueTemplateReference= $null
                                            value= "$domain\Domain Admins"
                                            }
                                            @{
                                            "@odata.type"= "#microsoft.graph.deviceManagementConfigurationStringSettingValue"
                                            settingValueTemplateReference= $null
                                            value= "$domain\$user"
                                        })
                                    })
                                 }
                             })
                         })
                    })
                }
                @{
                settingValueTemplateReference= $null
                children= @(@{
                    "@odata.type"= "#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance"
                    settingDefinitionId= "device_vendor_msft_policy_config_localusersandgroups_configure_groupconfiguration_accessgroup"
                    settingInstanceTemplateReference= $null
                    groupSettingCollectionValue= @(@{
                        settingValueTemplateReference= $null
                        children= @(@{
                            "@odata.type"= "#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance"
                            settingDefinitionId= "device_vendor_msft_policy_config_localusersandgroups_configure_groupconfiguration_accessgroup_desc"
                            settingInstanceTemplateReference= $null
                            choiceSettingCollectionValue= @(@{
                                    settingValueTemplateReference= $null
                                    value= "device_vendor_msft_policy_config_localusersandgroups_configure_groupconfiguration_accessgroup_desc_remotedesktopusers"
                                    children= @()
                                })
                        }
                        @{
                            "@odata.type"= "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance"
                            settingDefinitionId= "device_vendor_msft_policy_config_localusersandgroups_configure_groupconfiguration_accessgroup_action"
                            settingInstanceTemplateReference= $null
                            choiceSettingValue= @{
                                settingValueTemplateReference= $null
                                value= "device_vendor_msft_policy_config_localusersandgroups_configure_groupconfiguration_accessgroup_action_add_update"
                                children= @()
                            }
                        }
                        @{
                            "@odata.type"= "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance"
                            settingDefinitionId= "device_vendor_msft_policy_config_localusersandgroups_configure_groupconfiguration_accessgroup_userselectiontype"
                            settingInstanceTemplateReference= $null
                            choiceSettingValue= @{
                                settingValueTemplateReference= $null
                                value= "device_vendor_msft_policy_config_localusersandgroups_configure_groupconfiguration_accessgroup_userselectiontype_users"
                                children= @(@{
                                    "@odata.type"= "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance"
                                    settingDefinitionId= "device_vendor_msft_policy_config_localusersandgroups_configure_groupconfiguration_accessgroup_users"
                                    settingInstanceTemplateReference= $null
                                    simpleSettingCollectionValue= @(@{
                                        "@odata.type"= "#microsoft.graph.deviceManagementConfigurationStringSettingValue"
                                        settingValueTemplateReference= $null
                                        value= $RDPGRPSID
                                        })
                                })
                            }
                        })
                    })
                })
            }
            )
            }
        })
    }

    $policy = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies" -Body (ConvertTo-Json $policyBody -Depth 16)
    $policyId = $policy.id
    Write-Host "Policy ""WIN_AP_ADM-$computer"" erstellt: $policyId"

    
    # Policy zuweisen
    $assignmentBody = @{
        assignments = @(@{
            target = @{
                "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                 groupId = $groupId
            }
        })
    }

    Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$policyId/assign" -Headers $headers -Body ( ConvertTo-Json $assignmentBody -Depth 5)
    Write-Host "Policy für $user auf $computer erstellt und zugewiesen."

} #Foreach Ende
