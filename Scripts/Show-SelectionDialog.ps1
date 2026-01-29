<#
.SYNOPSIS
Displays a selection dialog for groups, filters, assignment type, and (optionally) intent for policy assignments.
Disables filter fields and enforces that if one filter field is filled, both must be filled.

.DESCRIPTION
This function loads a XAML-based selection dialog and populates its controls for group, filter, filter type, 
assignment type, and (optionally) intent. If the global policy type is one of 
deviceCustomAttributeShellScripts, intents, deviceShellScripts, or deviceManagementScripts, the filter fields 
are disabled. Additionally, if either filter field is filled in while the other is left blank, the user is 
prompted to complete both before continuing. The user selection is returned as a PSCustomObject.

.NOTES
Author: Maxime Guillemin | CloudFlow
Date: 09/07/2024

.EXAMPLE
$result = Show-SelectionDialog -groups $groupList -filters $filterList -includeIntent $true
if ($result) {
    # Process the returned selection
}
#>
function Show-SelectionDialog {
    param (
        [Parameter(Mandatory = $true)]
        [array]$groups,
        [Parameter(Mandatory = $false)]
        [array]$filters,
        [Parameter(Mandatory = $false)]
        [bool]$includeIntent = $false,
        [Parameter(Mandatory = $false)]
        [string]$appODataType,
        [Parameter(Mandatory = $false)]
        [bool]$isRemediationScript = $false
    )

    Write-IntuneToolkitLog "Show-SelectionDialog function called" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"

    # ---------------------------------------------------------------------------
    # Load the XAML file for the selection dialog.
    # ---------------------------------------------------------------------------
    # Resolve the XAML path relative to this script's location, pointing to the root XML folder
    $xamlPath = Join-Path -Path $PSScriptRoot -ChildPath "..\XML\SelectionDialog.xaml"
    if (-not (Test-Path $xamlPath)) {
        $errorMessage = "XAML file not found at $xamlPath"
        Write-Error $errorMessage
        Write-IntuneToolkitLog $errorMessage -component "Show-SelectionDialog" -file "SelectionDialog.ps1"
        return $null
    }

    # Read the entire XAML file as one string
    $xamlContent = Get-Content -Path $xamlPath -Raw -ErrorAction Stop
    Write-IntuneToolkitLog "Loaded XAML content from $xamlPath" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"

    # Parse the XAML into a Window object
    $xmlDoc = [xml]$xamlContent
    $reader = New-Object System.Xml.XmlNodeReader $xmlDoc
    $Window = [Windows.Markup.XamlReader]::Load($reader)
    if (-not $Window) {
        $errorMessage = "Failed to load XAML"
        Write-Error $errorMessage
        Write-IntuneToolkitLog $errorMessage -component "Show-SelectionDialog" -file "SelectionDialog.ps1"
        return $null
    }
    Write-IntuneToolkitLog "XAML loaded successfully" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"
    # Ensure the window appears on top and centered
    try {
        $Window.WindowStartupLocation = 'CenterScreen'
        $Window.Topmost = $true
    } catch {}

    # ---------------------------------------------------------------------------
    # Retrieve UI elements from the dialog.
    # ---------------------------------------------------------------------------
    $GroupSearchBox         = $Window.FindName("GroupSearchBox")
    $GroupComboBox          = $Window.FindName("GroupComboBox")
    $FilterComboBox         = $Window.FindName("FilterComboBox")
    $FilterTypeComboBox     = $Window.FindName("FilterTypeComboBox")
    $AssignmentTypeComboBox = $Window.FindName("AssignmentTypeComboBox")
    $IntentComboBox         = $Window.FindName("IntentComboBox")
    $IntentTextBlock        = $Window.FindName("IntentTextBlock")
    $OkButton               = $Window.FindName("OkButton")
    $CancelButton           = $Window.FindName("CancelButton")
    $AddExtraAssignmentButton   = $Window.FindName("AddExtraAssignmentButton")
    $NotificationsTextBlock     = $Window.FindName("NotificationsTextBlock")
    $NotificationsComboBox      = $Window.FindName("NotificationsComboBox")
    $DeliveryTextBlock          = $Window.FindName("DeliveryTextBlock")
    $DeliveryComboBox           = $Window.FindName("DeliveryComboBox")

    # Remediation Schedule Elements
    $ScheduleTypeTextBlock   = $Window.FindName("ScheduleTypeTextBlock")
    $ScheduleTypeComboBox    = $Window.FindName("ScheduleTypeComboBox")
    $IntervalTextBlock       = $Window.FindName("IntervalTextBlock")
    $IntervalTextBox         = $Window.FindName("IntervalTextBox")
    $RunRemediationCheckBox  = $Window.FindName("RunRemediationCheckBox")
    $DateTextBlock           = $Window.FindName("DateTextBlock")
    $StartDatePicker         = $Window.FindName("StartDatePicker")
    $TimeTextBlock           = $Window.FindName("TimeTextBlock")
    $TimeStackPanel          = $Window.FindName("TimeStackPanel")
    $HourComboBox            = $Window.FindName("HourComboBox")
    $MinuteComboBox          = $Window.FindName("MinuteComboBox")

    # ---------------------------------------------------------------------------
    # Validate that all required UI elements are found.
    # ---------------------------------------------------------------------------
    if (-not $GroupSearchBox) { Write-Error "GroupSearchBox not found"; Write-IntuneToolkitLog "GroupSearchBox not found" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"; return $null }
    if (-not $GroupComboBox) { Write-Error "GroupComboBox not found"; Write-IntuneToolkitLog "GroupComboBox not found" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"; return $null }
    if (-not $FilterComboBox) { Write-Error "FilterComboBox not found"; Write-IntuneToolkitLog "FilterComboBox not found" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"; return $null }
    if (-not $FilterTypeComboBox) { Write-Error "FilterTypeComboBox not found"; Write-IntuneToolkitLog "FilterTypeComboBox not found" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"; return $null }
    if (-not $AssignmentTypeComboBox) { Write-Error "AssignmentTypeComboBox not found"; Write-IntuneToolkitLog "AssignmentTypeComboBox not found" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"; return $null }
    if (-not $OkButton) { Write-Error "OkButton not found"; Write-IntuneToolkitLog "OkButton not found" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"; return $null }
    if (-not $CancelButton) { Write-Error "CancelButton not found"; Write-IntuneToolkitLog "CancelButton not found" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"; return $null }
    if (-not $AddExtraAssignmentButton) { Write-Error "AddExtraAssignmentButton not found"; Write-IntuneToolkitLog "AddExtraAssignmentButton not found" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"; return $null }
    if ($includeIntent -and (-not $IntentComboBox)) { Write-Error "IntentComboBox not found"; Write-IntuneToolkitLog "IntentComboBox not found" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"; return $null }

    Write-IntuneToolkitLog "UI elements found successfully" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"

    # ---------------------------------------------------------------------------
    # Set intent controls visible if included.
    # ---------------------------------------------------------------------------
    if ($includeIntent) {
        $IntentComboBox.Visibility = "Visible"
        $IntentTextBlock.Visibility = "Visible"
    }
    # Handle Win32 LOB App extra settings
    if ($appODataType -eq "#microsoft.graph.win32LobApp") {
        $NotificationsTextBlock.Visibility = "Visible"
        $NotificationsComboBox.Visibility = "Visible"
        $DeliveryTextBlock.Visibility     = "Visible"
        $DeliveryComboBox.Visibility      = "Visible"
        # Populate notification and delivery options
        $NotificationsComboBox.Items.Clear()
        foreach ($opt in @("showAll","showReboot","hideAll")) {
            $item = New-Object Windows.Controls.ComboBoxItem
            $item.Content = $opt
            $NotificationsComboBox.Items.Add($item)
        }
        $NotificationsComboBox.SelectedIndex = 0
        $DeliveryComboBox.Items.Clear()
        foreach ($opt in @("notConfigured","foreground")) {
            $item = New-Object Windows.Controls.ComboBoxItem
            $item.Content = $opt
            $DeliveryComboBox.Items.Add($item)
        }
        $DeliveryComboBox.SelectedIndex = 0
    } else {
        $NotificationsTextBlock.Visibility = "Collapsed"
        $NotificationsComboBox.Visibility = "Collapsed"
        $DeliveryTextBlock.Visibility     = "Collapsed"
        $DeliveryComboBox.Visibility      = "Collapsed"
    }

    # ---------------------------------------------------------------------------
    # Handle Remediation Script Schedule Logic
    # ---------------------------------------------------------------------------
    if ($isRemediationScript) {
        # Show main schedule type and checkbox
        $ScheduleTypeTextBlock.Visibility = "Visible"
        $ScheduleTypeComboBox.Visibility  = "Visible"
        $RunRemediationCheckBox.Visibility = "Visible"

        # Initialize Schedule Types
        $ScheduleTypeComboBox.Items.Clear()
        foreach ($st in @("Daily", "Hourly", "RunOnce")) {
            $item = New-Object Windows.Controls.ComboBoxItem
            $item.Content = $st
            $ScheduleTypeComboBox.Items.Add($item)
        }
        $ScheduleTypeComboBox.SelectedIndex = 0

        # Initialize Time Pickers (00-23, 00-59)
        $HourComboBox.Items.Clear()
        0..23 | ForEach-Object { $HourComboBox.Items.Add(("{0:D2}" -f $_)) } | Out-Null
        $HourComboBox.SelectedIndex = 0
        
        $MinuteComboBox.Items.Clear()
        0..59 | ForEach-Object { $MinuteComboBox.Items.Add(("{0:D2}" -f $_)) } | Out-Null
        $MinuteComboBox.SelectedIndex = 0

        # Logic to toggle visibility based on Schedule Type
        $updateVisibility = {
            if ($ScheduleTypeComboBox.SelectedItem) {
                $selectedType = $ScheduleTypeComboBox.SelectedItem.Content
                
                # Default everything to collapsed first
                $IntervalTextBlock.Visibility = "Collapsed"
                $IntervalTextBox.Visibility   = "Collapsed"
                $DateTextBlock.Visibility     = "Collapsed"
                $StartDatePicker.Visibility   = "Collapsed"
                $TimeTextBlock.Visibility     = "Collapsed"
                $TimeStackPanel.Visibility    = "Collapsed"

                if ($selectedType -eq "Hourly") {
                    $IntervalTextBlock.Visibility = "Visible"
                    $IntervalTextBox.Visibility   = "Visible"
                    $IntervalTextBlock.Text       = "Interval (Hours):"
                }
                elseif ($selectedType -eq "Daily") {
                    $IntervalTextBlock.Visibility = "Visible"
                    $IntervalTextBox.Visibility   = "Visible"
                    $IntervalTextBlock.Text       = "Interval (Days):"
                    $TimeTextBlock.Visibility     = "Visible"
                    $TimeStackPanel.Visibility    = "Visible"
                }
                elseif ($selectedType -eq "RunOnce") {
                    $DateTextBlock.Visibility     = "Visible"
                    $StartDatePicker.Visibility   = "Visible"
                    $TimeTextBlock.Visibility     = "Visible"
                    $TimeStackPanel.Visibility    = "Visible"
                    # RunOnce interval is implicitly 1, usually hidden or ignored, but we can hide it.
                }
            }
        }

        $ScheduleTypeComboBox.Add_SelectionChanged($updateVisibility)
        
        # Trigger initial selection logic
        & $updateVisibility

    } else {
        # Ensure everything is collapsed
        $ScheduleTypeTextBlock.Visibility = "Collapsed"
        $ScheduleTypeComboBox.Visibility  = "Collapsed"
        $RunRemediationCheckBox.Visibility= "Collapsed"
        $IntervalTextBlock.Visibility     = "Collapsed"
        $IntervalTextBox.Visibility       = "Collapsed"
        $DateTextBlock.Visibility         = "Collapsed"
        $StartDatePicker.Visibility       = "Collapsed"
        $TimeTextBlock.Visibility         = "Collapsed"
        $TimeStackPanel.Visibility        = "Collapsed"
    }

    # ---------------------------------------------------------------------------
    # Disable filter fields for specific policy types.
    # ---------------------------------------------------------------------------
    if (
        $global:CurrentPolicyType -in @(
            "deviceCustomAttributeShellScripts",
            "intents",
            "deviceShellScripts",
            "deviceManagementScripts",
            "windowsAutopilotDeploymentProfiles"  # Autopilot: filters not supported
        ) -or
        $appODataType -in @(
            "#microsoft.graph.macOSDmgApp",
            "#microsoft.graph.macOSPkgApp"
        )
    ) {
        $FilterComboBox.IsEnabled = $false
        $FilterTypeComboBox.IsEnabled = $false
        Write-IntuneToolkitLog "Filter fields disabled due to policy type or app type: $global:CurrentPolicyType / $appODataType" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"
    } else {
        $FilterComboBox.IsEnabled = $true
        $FilterTypeComboBox.IsEnabled = $true
    }

    # ---------------------------------------------------------------------------
    # Populate the group combo box based on the search text.
    # ---------------------------------------------------------------------------
    function Update-GroupComboBox {
        $GroupComboBox.Items.Clear()
        $searchText = $GroupSearchBox.Text.ToLower()
        foreach ($group in $groups) {
            if ($group.DisplayName -and $group.DisplayName.ToLower().Contains($searchText)) {
                $comboBoxItem = New-Object Windows.Controls.ComboBoxItem
                $comboBoxItem.Content = $group.DisplayName
                $comboBoxItem.Tag = $group.Id
                $GroupComboBox.Items.Add($comboBoxItem)
            }
        }
    }
    Update-GroupComboBox
    Write-IntuneToolkitLog "Initial population of group combo box completed" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"

    # Update the group combo box as the user types.
    $GroupSearchBox.Add_TextChanged({ Update-GroupComboBox })

    # ---------------------------------------------------------------------------
    # Populate the filter combo box.
    # ---------------------------------------------------------------------------
    if ($null -ne $filters) {
        foreach ($filter in $filters) {
            $comboBoxItem = New-Object Windows.Controls.ComboBoxItem
            $comboBoxItem.Content = $filter.displayName
            $comboBoxItem.Tag = $filter.id
            $FilterComboBox.Items.Add($comboBoxItem)
        }
        Write-IntuneToolkitLog "Populated filter combo box" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"
    } else {
        $comboBoxItem = New-Object Windows.Controls.ComboBoxItem
        $comboBoxItem.Content = "No Filters"
        $FilterComboBox.Items.Add($comboBoxItem)
        Write-IntuneToolkitLog "No filters available to populate filter combo box" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"
    }

    # ---------------------------------------------------------------------------
    # Populate the filter type combo box with include and exclude options.
    # ---------------------------------------------------------------------------
    $includeItem = New-Object Windows.Controls.ComboBoxItem
    $includeItem.Content = "include"
    $FilterTypeComboBox.Items.Add($includeItem)

    $excludeItem = New-Object Windows.Controls.ComboBoxItem
    $excludeItem.Content = "exclude"
    $FilterTypeComboBox.Items.Add($excludeItem)
    Write-IntuneToolkitLog "Populated filter type combo box with include and exclude options" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"

    # ---------------------------------------------------------------------------
    # Populate intent options if required.
    # ---------------------------------------------------------------------------
    if ($includeIntent) {
        if ($IntentComboBox.Items.Count -eq 0) {
            $availableItem = New-Object Windows.Controls.ComboBoxItem
            $availableItem.Content = "Available"
            $IntentComboBox.Items.Add($availableItem)

            $requiredItem = New-Object Windows.Controls.ComboBoxItem
            $requiredItem.Content = "Required"
            $IntentComboBox.Items.Add($requiredItem)

            $uninstallItem = New-Object Windows.Controls.ComboBoxItem
            $uninstallItem.Content = "Uninstall"
            $IntentComboBox.Items.Add($uninstallItem)
            Write-IntuneToolkitLog "Populated intent combo box with available, required, and uninstall options" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"
        }
    }

    # ---------------------------------------------------------------------------
    # Initialize the selection object.
    # ---------------------------------------------------------------------------
    $selection = [PSCustomObject]@{
        Group                        = $null
        Filter                       = $null
        FilterType                   = $null
        AssignmentType               = $null
        Intent                       = $null
        Notifications                = $null
        DeliveryOptimizationPriority = $null
        # Remediation specific
        ScheduleType                 = $null
        Interval                     = $null
        StartDate                    = $null
        StartTime                    = $null
        RunRemediation               = $null
    }
    $script:DialogResult = "OK"

    # ---------------------------------------------------------------------------
    # OK button event: capture user selections and enforce filter safety.
    # ---------------------------------------------------------------------------
    $OkButton.Add_Click({
        if ($FilterComboBox.IsEnabled -and (
                ($FilterComboBox.SelectedItem -and -not $FilterTypeComboBox.SelectedItem) -or
                (-not $FilterComboBox.SelectedItem -and $FilterTypeComboBox.SelectedItem)
            )) {
            [System.Windows.MessageBox]::Show("If you wish to apply a filter, please select both a filter and a filter type.","Incomplete Filter Selection")
            return
        }
        $selection.Group = $GroupComboBox.SelectedItem
        $selection.Filter = $FilterComboBox.SelectedItem
        $selection.FilterType = $FilterTypeComboBox.SelectedItem
        $selection.AssignmentType = $AssignmentTypeComboBox.SelectedItem
        if ($includeIntent) {
            $selection.Intent = $IntentComboBox.SelectedItem.Content
        }
        if ($NotificationsComboBox.Visibility -eq 'Visible') {
            $selection.Notifications = $NotificationsComboBox.SelectedItem.Content
        }
        if ($DeliveryComboBox.Visibility -eq 'Visible') {
            $selection.DeliveryOptimizationPriority = $DeliveryComboBox.SelectedItem.Content
        }
        
        # Capture Remediation Schedule
        if ($isRemediationScript) {
            $selection.ScheduleType   = $ScheduleTypeComboBox.SelectedItem.Content
            $selection.Interval       = $IntervalTextBox.Text
            $selection.RunRemediation = $RunRemediationCheckBox.IsChecked
            
            if ($StartDatePicker.Visibility -eq 'Visible') {
                $selection.StartDate = $StartDatePicker.SelectedDate
            }
            if ($TimeStackPanel.Visibility -eq 'Visible') {
                $selection.StartTime = "{0}:{1}:00" -f $HourComboBox.SelectedItem, $MinuteComboBox.SelectedItem
            }
            
            # Simple validation for Interval
            if ($IntervalTextBox.Visibility -eq 'Visible' -and -not [int]::TryParse($IntervalTextBox.Text, [ref]$null)) {
                 [System.Windows.MessageBox]::Show("Please enter a valid number for Interval.")
                 return
            }
        }

        $script:DialogResult = "OK"
        $Window.Close()
    })

    # ---------------------------------------------------------------------------
    # Add Extra Assignment button event: same as OK but sets a different result.
    # ---------------------------------------------------------------------------
    $AddExtraAssignmentButton.Add_Click({
        if ($FilterComboBox.IsEnabled -and (
                ($FilterComboBox.SelectedItem -and -not $FilterTypeComboBox.SelectedItem) -or
                (-not $FilterComboBox.SelectedItem -and $FilterTypeComboBox.SelectedItem)
            )) {
            [System.Windows.MessageBox]::Show("If you wish to apply a filter, please select both a filter and a filter type.","Incomplete Filter Selection")
            return
        }
        $selection.Group = $GroupComboBox.SelectedItem
        $selection.Filter = $FilterComboBox.SelectedItem
        $selection.FilterType = $FilterTypeComboBox.SelectedItem
        $selection.AssignmentType = $AssignmentTypeComboBox.SelectedItem
        if ($includeIntent) {
            $selection.Intent = $IntentComboBox.SelectedItem.Content
        }
        if ($NotificationsComboBox.Visibility -eq 'Visible') {
            $selection.Notifications = $NotificationsComboBox.SelectedItem.Content
        }
        if ($DeliveryComboBox.Visibility -eq 'Visible') {
            $selection.DeliveryOptimizationPriority = $DeliveryComboBox.SelectedItem.Content
        }
        
        # Capture Remediation Schedule (Duplicate logic for AddExtra)
        if ($isRemediationScript) {
            $selection.ScheduleType   = $ScheduleTypeComboBox.SelectedItem.Content
            $selection.Interval       = $IntervalTextBox.Text
            $selection.RunRemediation = $RunRemediationCheckBox.IsChecked
            
            if ($StartDatePicker.Visibility -eq 'Visible') {
                $selection.StartDate = $StartDatePicker.SelectedDate
            }
            if ($TimeStackPanel.Visibility -eq 'Visible') {
                $selection.StartTime = "{0}:{1}:00" -f $HourComboBox.SelectedItem, $MinuteComboBox.SelectedItem
            }
             # Simple validation for Interval
            if ($IntervalTextBox.Visibility -eq 'Visible' -and -not [int]::TryParse($IntervalTextBox.Text, [ref]$null)) {
                 [System.Windows.MessageBox]::Show("Please enter a valid number for Interval.")
                 return
            }
        }
        
        $script:DialogResult = "AddExtra"
        $Window.Close()
    })

    # ---------------------------------------------------------------------------
    # Cancel button event: close the dialog.
    # ---------------------------------------------------------------------------
    $CancelButton.Add_Click({
        Write-IntuneToolkitLog "Selection dialog canceled by user" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"
        $script:DialogResult = "Cancel"
        $Window.Close()
    })

    # Ensure the window is activated on top
    try {
        $Window.ShowActivated = $true
        $Window.Activate()
        $Window.Focus()
    } catch {}
    Set-WindowIcon -Window $Window
    $Window.ShowDialog() | Out-Null

    # ---------------------------------------------------------------------------
    # Return the selection and dialog result.
    # ---------------------------------------------------------------------------
    if ($script:DialogResult -eq "Cancel") {
        return $null
    }
    if ($selection.Group -and $selection.Group.Tag) {
        Write-IntuneToolkitLog "Returning selected items" -component "Show-SelectionDialog" -file "SelectionDialog.ps1"
        return @{
            Group                        = $selection.Group
            Filter                       = $selection.Filter
            FilterType                   = if ($selection.FilterType) { $selection.FilterType.Content } else { $null }
            AssignmentType               = if ($selection.AssignmentType) { $selection.AssignmentType.Content } else { "Include" }
            Intent                       = $selection.Intent
            Notifications                = $selection.Notifications
            DeliveryOptimizationPriority = $selection.DeliveryOptimizationPriority
            ScheduleType                 = $selection.ScheduleType
            Interval                     = $selection.Interval
            StartDate                    = $selection.StartDate
            StartTime                    = $selection.StartTime
            RunRemediation               = $selection.RunRemediation
            DialogResult                 = $script:DialogResult
        }
    } else {
        $errorMessage = "No group selected"
        Write-Error $errorMessage
        Write-IntuneToolkitLog $errorMessage -component "Show-SelectionDialog" -file "SelectionDialog.ps1"
        return $null
    }
}