<#
.SYNOPSIS
Handles the deletion of selected policies or applications.
This is a destructive action and requires confirmation.
#>

$DeletePolicyButton.Add_Click({
    Write-IntuneToolkitLog "DeletePolicyButton clicked" -component "DeletePolicy-Button" -file "DeletePolicyButton.ps1"

    try {
        $selectedPolicies = $PolicyDataGrid.SelectedItems

        if ($selectedPolicies -and $selectedPolicies.Count -gt 0) {
            # Determine friendly name for the current policy type
            $typeName = switch ($global:CurrentPolicyType) {
                "mobileApps"                        { "Application" }
                "mobileAppConfigurations"           { "App Config" }
                "configurationPolicies"             { "Settings Catalog" }
                "deviceManagementScripts"           { "Platform Script" }
                "deviceHealthScripts"               { "Remediation Script" }
                "deviceShellScripts"                { "Shell Script" }
                "deviceCustomAttributeShellScripts" { "Custom Attribute" }
                "windowsAutopilotDeploymentProfiles"{ "Autopilot Profile" }
                "intents"                           { "Endpoint Security Policy" }
                "deviceConfigurations"              { "Device Config" }
                "deviceCompliancePolicies"          { "Compliance Policy" }
                "groupPolicyConfigurations"         { "Admin Template" }
                default                             { "Policy" }
            }

            # Build a summary string of items to be deleted
            $summaryLines = @()
            foreach ($policy in $selectedPolicies) {
                $line = "$($typeName): $($policy.PolicyName) (ID: $($policy.PolicyId))"
                $summaryLines += $line
            }
            $summaryText = "The following $($typeName)s will be PERMANENTLY DELETED:`n`n" + ($summaryLines -join "`n")
            $summaryText += "`n`nThis action cannot be undone.`nAre you sure you want to proceed?"

            # Use the custom confirmation dialog with "Delete" button in Red and correct Title
            $confirm = Show-ConfirmationDialog -SummaryText $summaryText -ConfirmButtonText "Delete" -ConfirmButtonColor "Red" -Title "Confirm Deletion"

            if ($confirm) {
                # Process Deletion
                foreach ($policy in $selectedPolicies) {
                    $policyId = $policy.PolicyId
                    Write-IntuneToolkitLog "Deleting policy: $policyId ($($policy.PolicyName))" -component "DeletePolicy-Button" -file "DeletePolicyButton.ps1"

                    # Construct URL based on policy type
                    # Logic mirrors Load-PolicyData and DeleteAssignmentButton patterns
                    if ($global:CurrentPolicyType -eq "mobileApps") {
                        # Mobile Apps
                        $url = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$policyId"
                    }
                    elseif ($global:CurrentPolicyType -eq "mobileAppConfigurations") {
                        $url = "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppConfigurations/$policyId"
                    }
                    elseif ($global:CurrentPolicyType -eq "configurationPolicies") {
                        # Settings Catalog
                        $url = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$policyId"
                    }
                    elseif ($global:CurrentPolicyType -eq "deviceManagementScripts") {
                        # Remediation / Platform Scripts (generic)
                         $url = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/$policyId"
                    }
                    elseif ($global:CurrentPolicyType -eq "deviceHealthScripts") {
                        # Remediations
                        $url = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$policyId"
                    }
                     elseif ($global:CurrentPolicyType -eq "deviceShellScripts") {
                        # macOS Shell Scripts
                        $url = "https://graph.microsoft.com/beta/deviceManagement/deviceShellScripts/$policyId"
                    }
                    elseif ($global:CurrentPolicyType -eq "deviceCustomAttributeShellScripts") {
                        # macOS Custom Attributes
                        $url = "https://graph.microsoft.com/beta/deviceManagement/deviceCustomAttributeShellScripts/$policyId"
                    }
                    elseif ($global:CurrentPolicyType -eq "windowsAutopilotDeploymentProfiles") {
                        # Autopilot
                        $url = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles/$policyId"
                    }
                    elseif ($global:CurrentPolicyType -eq "intents") {
                        # Endpoint Security
                         $url = "https://graph.microsoft.com/beta/deviceManagement/intents/$policyId"
                    }
                    elseif ($global:CurrentPolicyType -eq "deviceConfigurations") {
                        # Legacy device config
                        $url = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$policyId"
                    }
                    elseif ($global:CurrentPolicyType -eq "deviceCompliancePolicies") {
                        # Compliance
                        $url = "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies/$policyId"
                    }
                    elseif ($global:CurrentPolicyType -eq "groupPolicyConfigurations") {
                        # ADMX import
                        $url = "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$policyId"
                    }
                    else {
                         # Generic fallback
                        $url = "https://graph.microsoft.com/beta/deviceManagement/$($global:CurrentPolicyType)/$policyId"
                    }

                    Write-IntuneToolkitLog "Delete URL: $url" -component "DeletePolicy-Button" -file "DeletePolicyButton.ps1"
                    Invoke-MgGraphRequest -Uri $url -Method DELETE
                }

                [System.Windows.Forms.MessageBox]::Show("Deletion completed.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

                # Refresh DataGrid
                Write-IntuneToolkitLog "Refreshing DataGrid" -component "DeletePolicy-Button" -file "DeletePolicyButton.ps1"
                Load-PolicyData -policyType $global:CurrentPolicyType -loadingMessage "Reloading data..." -loadedMessage "Data reloaded."
            }
        } else {
            [System.Windows.Forms.MessageBox]::Show("Please select at least one item to delete.", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
    catch {
        $errorMessage = "Failed to delete policy. Error: $($_.Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show($errorMessage, "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        Write-IntuneToolkitLog $errorMessage -component "DeletePolicy-Button" -file "DeletePolicyButton.ps1"
    }
})
