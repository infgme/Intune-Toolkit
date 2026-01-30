# Global Group Search Logic

$GlobalGroupSearchButton.Add_Click({
    # 1. Select Group
    # Force Checked state (visual) since we are activating this view
    if ($GlobalGroupSearchButton.IsChecked -eq $false) { $GlobalGroupSearchButton.IsChecked = $true }

    if (-not $global:AllSecurityGroups) {
        $StatusText.Text = "Security Groups not loaded. please wait..."
        $GlobalGroupSearchButton.IsChecked = $false
        return
    }

    $selectedGroup = Show-GroupSearchDialog -AllGroups $global:AllSecurityGroups
    
    if (-not $selectedGroup) {
        $StatusText.Text = "Group Search Cancelled."
        # If we just switched to this tab but cancelled, maybe valid to uncheck? 
        # But if we were already here, unchecking leaves us with nothing selected.
        # Simple approach: Uncheck to signal "Action aborted".
        $GlobalGroupSearchButton.IsChecked = $false
        return
    }
    
    $targetGroupId = $selectedGroup.Id
    $targetGroupName = $selectedGroup.DisplayName
    
    # 2. Prepare UI
    $StatusText.Text = "Initializing Global Search for '$targetGroupName'..."
    $GlobalSearchProgressBar.Visibility = "Visible"
    $GlobalSearchProgressBar.Value = 0
    $PolicyDataGrid.Visibility = "Hidden" # Hide grid while searching
    
    # Run in a separate thread context or just process events to keep UI alive?
    # WPF simple approach: Process events inside the loop often.
    # ideally we use background jobs but that complicates shared variable access (DataGrid).
    # We will accept brief freezes but update UI between steps.
    [System.Windows.Forms.Application]::DoEvents()

    # 3. Prepare Lookups (Required for Process-Assignment)
    $groupLookup = @{}
    foreach ($g in $global:AllSecurityGroups) { $groupLookup[$g.Id] = $g.DisplayName }
    
    # Fetch all filters once (optimization)
    $allFilters = Get-AllAssignmentFilters
    $filterLookup = @{}
    foreach ($f in $allFilters) { $filterLookup[$f.Id] = $f.DisplayName }
    
    # 4. Define Search Targets
    # Format: @{ Type="Display Name"; Url="GraphURL"; ODataType="OptionalType" }
    $searchTargets = @(
        @{ Type="Device Configurations"; Url="https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$expand=assignments" },
        @{ Type="Compliance Policies"; Url="https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies?`$expand=assignments" },
        @{ Type="Mobile Apps"; Url="https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$filter=(microsoft.graph.managedApp/appAvailability%20eq%20null%20or%20microsoft.graph.managedApp/appAvailability%20eq%20%27lineOfBusiness%27%20or%20isAssigned%20eq%20true)&`$expand=assignments" },
        @{ Type="App Config Policies"; Url="https://graph.microsoft.com/beta/deviceAppManagement/mobileAppConfigurations?`$expand=assignments" },
        @{ Type="Endpoint Security Intents"; Url="https://graph.microsoft.com/beta/deviceManagement/intents?`$expand=assignments" },
        @{ Type="Settings Catalog"; Url="https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$expand=assignments" },
        @{ Type="Administrative Templates"; Url="https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations?`$expand=assignments" },
        @{ Type="Platform Scripts"; Url="https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts?`$expand=assignments" },
        @{ Type="Remediation Scripts"; Url="https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts?`$expand=assignments" },
        @{ Type="macOS Scripts"; Url="https://graph.microsoft.com/beta/deviceManagement/deviceShellScripts?`$expand=assignments" },
        @{ Type="macOS Custom Attributes"; Url="https://graph.microsoft.com/beta/deviceManagement/deviceCustomAttributeShellScripts?`$expand=assignments" },
        @{ Type="Autopilot Profiles"; Url="https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles?`$expand=assignments" }
    )

    $GlobalSearchProgressBar.Maximum = $searchTargets.Count
    $global:AllPolicyData = @() # Clear current grid
    
    $foundCount = 0

    foreach ($target in $searchTargets) {
        $StatusText.Text = "Searching in $($target.Type)..."
        [System.Windows.Forms.Application]::DoEvents() # Keep UI responsive
        
        try {
            $policies = Get-GraphData -url $target.Url
            
            foreach ($policy in $policies) {
                # Check assignments
                if ($policy.assignments) {
                    foreach ($assignment in $policy.assignments) {
                        if ($assignment.target -and $assignment.target.groupId -eq $targetGroupId) {
                            # MATCH FOUND
                            $foundCount++
                            
                            # Determine Platform (Simplified logic from Functions.ps1)
                             if ($target.Type -eq "Mobile Apps") {
                                $platform = Get-PlatformApps -odataType $policy.'@odata.type'
                                $isMobileApp = $true
                            } elseif ($target.Type -match "Scripts") {
                                $platform = if ($target.Type -match "macOS") { "macOS" } else { "Windows" }
                                $isMobileApp = $false
                            } elseif ($target.Type -eq "Administrative Templates" -or $target.Type -eq "Endpoint Security Intents" -or $target.Type -eq "Autopilot Profiles") {
                                $platform = "Windows"
                                $isMobileApp = $false
                            } else {
                                $platform = Get-DevicePlatform -OdataType $policy.platforms
                                if (-not $platform) {
                                     $platform = Get-DevicePlatform -OdataType $policy.'@odata.type'
                                }
                                $isMobileApp = $false
                            }

                            # Process Assignment to get formatted object
                            $processedRow = Process-Assignment -policy $policy `
                                                               -assignment $assignment `
                                                               -platform $platform `
                                                               -groupLookup $groupLookup `
                                                               -filterLookup $filterLookup `
                                                               -isMobileApp $isMobileApp
                            
                            # Add Policy Type for Global Search Grid - user requested column
                            $processedRow | Add-Member -MemberType NoteProperty -Name "PolicyType" -Value $target.Type
                            
                            $global:AllPolicyData += $processedRow
                        }
                    }
                }
            }
            
        } catch {
             Write-IntuneToolkitLog "Error searching $($target.Type): $($_.Exception.Message)"
        }
        
        $GlobalSearchProgressBar.Value += 1
    }

    # 5. Finalize
    $PolicyDataGrid.ItemsSource = $global:AllPolicyData
    $PolicyDataGrid.Items.Refresh()
    $PolicyDataGrid.Visibility = "Visible"
    $GlobalSearchProgressBar.Visibility = "Collapsed"

    # Set Search Mode and Default to Reports View
    $global:IsGlobalSearchMode = $true
    $ActionsToggle.IsChecked = $false
    $ReportsToggle.IsChecked = $true
    Set-BottomButtons -showActions $false
    
    $StatusText.Text = "Search Complete: Found $foundCount policies assigned to '$targetGroupName'."
    
    # Disable sidebar toggle buttons to indicate we are in a special view?
    # For now, just leaving them enabled allows user to switch back to normal view easily.
})
