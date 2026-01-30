# Attach the click event handler to the existing $ConnectEnterpriseAppButton
$ConnectEnterpriseAppButton.Add_Click({

    # Registry path for storing tenant configurations (HKEY_CURRENT_USER - no admin required)
    $script:RegistryPath = "HKCU:\Software\IntuneToolkit\TenantConfigs"

    # Helper function to get saved tenant configurations
    function Get-SavedTenantConfigs {
        if (-not (Test-Path $script:RegistryPath)) {
            return New-Object System.Collections.ArrayList
        }
        
        $configs = New-Object System.Collections.ArrayList
        Get-ChildItem -Path $script:RegistryPath -ErrorAction SilentlyContinue | ForEach-Object {
            [void]$configs.Add($_.PSChildName)
        }
        return $configs
    }

    # Helper function to save tenant configuration
    function Save-TenantConfig {
        param(
            [string]$ConfigName,
            [string]$TenantId,
            [string]$AppId,
            [string]$AuthMethod,
            [string]$CertThumbprint = ""
        )
        
        try {
            # Create registry path if it doesn't exist
            if (-not (Test-Path $script:RegistryPath)) {
                New-Item -Path $script:RegistryPath -Force | Out-Null
            }
            
            $configPath = Join-Path $script:RegistryPath $ConfigName
            if (-not (Test-Path $configPath)) {
                New-Item -Path $configPath -Force | Out-Null
            }
            
            # Save configuration values
            Set-ItemProperty -Path $configPath -Name "TenantId" -Value $TenantId
            Set-ItemProperty -Path $configPath -Name "AppId" -Value $AppId
            Set-ItemProperty -Path $configPath -Name "AuthMethod" -Value $AuthMethod
            
            if ($CertThumbprint) {
                Set-ItemProperty -Path $configPath -Name "CertThumbprint" -Value $CertThumbprint
            }
            
            Write-IntuneToolkitLog "Saved tenant configuration: $ConfigName" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            return $true
        }
        catch {
            Write-IntuneToolkitLog "Error saving tenant configuration: $($_.Exception.Message)" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            return $false
        }
    }

    # Helper function to load tenant configuration
    function Load-TenantConfig {
        param([string]$ConfigName)
        
        try {
            $configPath = Join-Path $script:RegistryPath $ConfigName
            if (-not (Test-Path $configPath)) {
                return $null
            }
            
            $config = @{
                TenantId = (Get-ItemProperty -Path $configPath -Name "TenantId" -ErrorAction SilentlyContinue).TenantId
                AppId = (Get-ItemProperty -Path $configPath -Name "AppId" -ErrorAction SilentlyContinue).AppId
                AuthMethod = (Get-ItemProperty -Path $configPath -Name "AuthMethod" -ErrorAction SilentlyContinue).AuthMethod
                CertThumbprint = (Get-ItemProperty -Path $configPath -Name "CertThumbprint" -ErrorAction SilentlyContinue).CertThumbprint
            }
            
            Write-IntuneToolkitLog "Loaded tenant configuration: $ConfigName" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            return $config
        }
        catch {
            Write-IntuneToolkitLog "Error loading tenant configuration: $($_.Exception.Message)" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            return $null
        }
    }

    # Helper function to delete tenant configuration
    function Remove-TenantConfig {
        param([string]$ConfigName)
        
        try {
            $configPath = Join-Path $script:RegistryPath $ConfigName
            if (Test-Path $configPath) {
                Remove-Item -Path $configPath -Recurse -Force
                Write-IntuneToolkitLog "Deleted tenant configuration: $ConfigName" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
                return $true
            }
            return $false
        }
        catch {
            Write-IntuneToolkitLog "Error deleting tenant configuration: $($_.Exception.Message)" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            return $false
        }
    }

    # Define the path to the external XAML file
    $XAMLPath = ".\XML\AuthMethodSelectionWindow.xaml"

    # Load the XAML from the file
    if (-not (Test-Path $XAMLPath)) {
        Write-IntuneToolkitLog "XAML file not found at path: $XAMLPath" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
        $StatusText.Text = "Error: XAML file not found."
        return
    }

    Write-IntuneToolkitLog "Loading XAML from: $XAMLPath" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"

    # Read the XAML content from the file
    [xml]$XAML = Get-Content -Path $XAMLPath

    # Load the XAML and show the window
    [void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$XAML.OuterXml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    Write-IntuneToolkitLog "XAML window loaded successfully" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"

    # Get access to tenant selector controls
    $SavedTenantsComboBox = $window.FindName("SavedTenantsComboBox")
    $LoadConfigButton = $window.FindName("LoadConfigButton")
    $DeleteConfigButton = $window.FindName("DeleteConfigButton")
    $SaveConfigButton = $window.FindName("SaveConfigButton")

    # Get access to radio buttons
    $RadioButtonClientSecret = $window.FindName("RadioButtonClientSecret")
    $RadioButtonCertificate = $window.FindName("RadioButtonCertificate")
    $RadioButtonInteractive = $window.FindName("RadioButtonInteractive")

    # Get access to input panels
    $ClientSecretInputPanel = $window.FindName("ClientSecretInputPanel")
    $CertificateInputPanel = $window.FindName("CertificateInputPanel")
    $InteractiveInputPanel = $window.FindName("InteractiveInputPanel")

    # Get access to input fields - Client Secret
    $TenantIDTextBox = $window.FindName("TenantIDTextBox")
    $AppIDTextBox = $window.FindName("AppIDTextBox")
    $AppSecretTextBox = $window.FindName("AppSecretTextBox")

    # Get access to input fields - Certificate
    $TenantIDTextBoxCert = $window.FindName("TenantIDTextBoxCert")
    $AppIDTextBoxCert = $window.FindName("AppIDTextBoxCert")
    $CertThumbprintTextBox = $window.FindName("CertThumbprintTextBox")
    $BrowseCertButton = $window.FindName("BrowseCertButton")

    # Get access to input fields - Interactive
    $TenantIDTextBoxInt = $window.FindName("TenantIDTextBoxInt")
    $AppIDTextBoxInt = $window.FindName("AppIDTextBoxInt")
    $ScopesTextBox = $window.FindName("ScopesTextBox")

    # Get submit button
    $SubmitButton = $window.FindName("SubmitButton")

    # Load saved tenant configurations into ComboBox
    $savedConfigs = Get-SavedTenantConfigs
    $SavedTenantsComboBox.Items.Clear()
    foreach ($config in $savedConfigs) {
        [void]$SavedTenantsComboBox.Items.Add($config)
    }
    if ($SavedTenantsComboBox.Items.Count -gt 0) {
        $SavedTenantsComboBox.SelectedIndex = 0
    }

    # Load Configuration button handler
    $LoadConfigButton.Add_Click({
        $selectedConfig = $SavedTenantsComboBox.SelectedItem
        if (-not $selectedConfig) {
            [System.Windows.MessageBox]::Show("Please select a configuration to load.", "No Selection", "OK", "Warning")
            return
        }
        
        $config = Load-TenantConfig -ConfigName $selectedConfig
        if ($config) {
            # Set authentication method
            switch ($config.AuthMethod) {
                "ClientSecret" {
                    $RadioButtonClientSecret.IsChecked = $true
                    $TenantIDTextBox.Text = $config.TenantId
                    $AppIDTextBox.Text = $config.AppId
                }
                "Certificate" {
                    $RadioButtonCertificate.IsChecked = $true
                    $TenantIDTextBoxCert.Text = $config.TenantId
                    $AppIDTextBoxCert.Text = $config.AppId
                    $CertThumbprintTextBox.Text = $config.CertThumbprint
                }
                "Interactive" {
                    $RadioButtonInteractive.IsChecked = $true
                    $TenantIDTextBoxInt.Text = $config.TenantId
                    $AppIDTextBoxInt.Text = $config.AppId
                }
            }
            # Success - no popup, just loaded silently
        }
        else {
            [System.Windows.MessageBox]::Show("Failed to load configuration.", "Error", "OK", "Error")
        }
    })

    # Delete Configuration button handler
    $DeleteConfigButton.Add_Click({
        $selectedConfig = $SavedTenantsComboBox.SelectedItem
        if (-not $selectedConfig) {
            [System.Windows.MessageBox]::Show("Please select a configuration to delete.", "No Selection", "OK", "Warning")
            return
        }
        
        $result = [System.Windows.MessageBox]::Show("Are you sure you want to delete configuration '$selectedConfig'?", "Confirm Deletion", "YesNo", "Question")
        if ($result -eq "Yes") {
            if (Remove-TenantConfig -ConfigName $selectedConfig) {
                # Refresh ComboBox
                $savedConfigs = Get-SavedTenantConfigs
                $SavedTenantsComboBox.Items.Clear()
                foreach ($config in $savedConfigs) {
                    [void]$SavedTenantsComboBox.Items.Add($config)
                }
                if ($SavedTenantsComboBox.Items.Count -gt 0) {
                    $SavedTenantsComboBox.SelectedIndex = 0
                }
                [System.Windows.MessageBox]::Show("Configuration deleted successfully.", "Success", "OK", "Information")
            }
            else {
                [System.Windows.MessageBox]::Show("Failed to delete configuration.", "Error", "OK", "Error")
            }
        }
    })

    # Save Configuration button handler
    $SaveConfigButton.Add_Click({
        Write-IntuneToolkitLog "Save Configuration button clicked" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
        
        # Show custom input dialog for configuration name
        try {
            Write-IntuneToolkitLog "Loading InputDialog.xaml" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            $inputDialogXaml = Get-Content "$PSScriptRoot\..\XML\InputDialog.xaml" -Raw
            $inputDialogReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$inputDialogXaml)
            $inputDialog = [Windows.Markup.XamlReader]::Load($inputDialogReader)
            
            $inputPromptText = $inputDialog.FindName("PromptText")
            $inputTextBox = $inputDialog.FindName("InputTextBox")
            $inputOKButton = $inputDialog.FindName("OKButton")
            $inputCancelButton = $inputDialog.FindName("CancelButton")
            
            $inputPromptText.Text = "Enter a name for this configuration:"
            $inputDialog.Title = "Save Configuration"
            
            # Set the window icon
            Set-WindowIcon -Window $inputDialog
            Write-IntuneToolkitLog "InputDialog loaded successfully" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            
            # Use script scope for dialog result
            $script:dialogResult = $false
            $inputOKButton.Add_Click({
                Write-IntuneToolkitLog "OK button clicked in InputDialog" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
                $script:dialogResult = $true
                $inputDialog.Close()
            })
            
            $inputCancelButton.Add_Click({
                Write-IntuneToolkitLog "Cancel button clicked in InputDialog" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
                $inputDialog.Close()
            })
            
            $inputDialog.Owner = $authWindow
            $null = $inputDialog.ShowDialog()
            
            if (-not $script:dialogResult) {
                Write-IntuneToolkitLog "Dialog cancelled or closed without saving" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
                return
            }
            
            $baseName = $inputTextBox.Text
            Write-IntuneToolkitLog "User entered configuration name: '$baseName'" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            
            if ([string]::IsNullOrWhiteSpace($baseName)) {
                Write-IntuneToolkitLog "Configuration name is empty, aborting save" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
                return
            }
        }
        catch {
            Write-IntuneToolkitLog "Error loading InputDialog: $($_.Exception.Message)" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            [System.Windows.MessageBox]::Show("Error loading input dialog: $($_.Exception.Message)", "Error", "OK", "Error")
            return
        }
        
        # Determine current authentication method and gather data
        $authMethod = ""
        $authSuffix = ""
        $tenantId = ""
        $appId = ""
        $certThumbprint = ""
        
        if ($RadioButtonClientSecret.IsChecked) {
            $authMethod = "ClientSecret"
            $authSuffix = " (Client Secret)"
            $tenantId = $TenantIDTextBox.Text
            $appId = $AppIDTextBox.Text
            Write-IntuneToolkitLog "Detected Client Secret authentication method" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            
            if ([string]::IsNullOrWhiteSpace($tenantId) -or [string]::IsNullOrWhiteSpace($appId)) {
                Write-IntuneToolkitLog "Missing Tenant ID or App ID for Client Secret method" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
                [System.Windows.MessageBox]::Show("Please fill in Tenant ID and App ID before saving.", "Missing Information", "OK", "Warning")
                return
            }
        }
        elseif ($RadioButtonCertificate.IsChecked) {
            $authMethod = "Certificate"
            $authSuffix = " (Certificate)"
            $tenantId = $TenantIDTextBoxCert.Text
            $appId = $AppIDTextBoxCert.Text
            $certThumbprint = $CertThumbprintTextBox.Text
            Write-IntuneToolkitLog "Detected Certificate authentication method" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            
            if ([string]::IsNullOrWhiteSpace($tenantId) -or [string]::IsNullOrWhiteSpace($appId)) {
                Write-IntuneToolkitLog "Missing Tenant ID or App ID for Certificate method" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
                [System.Windows.MessageBox]::Show("Please fill in Tenant ID and App ID before saving.", "Missing Information", "OK", "Warning")
                return
            }
        }
        elseif ($RadioButtonInteractive.IsChecked) {
            $authMethod = "Interactive"
            $authSuffix = " (Interactive)"
            $tenantId = $TenantIDTextBoxInt.Text
            $appId = $AppIDTextBoxInt.Text
            Write-IntuneToolkitLog "Detected Interactive authentication method" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
        }
        
        # Combine base name with auth method suffix
        $configName = $baseName + $authSuffix
        Write-IntuneToolkitLog "Saving configuration as: '$configName'" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
        Write-IntuneToolkitLog "Configuration details - TenantId: '$tenantId', AppId: '$appId', AuthMethod: '$authMethod'" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
        
        if (Save-TenantConfig -ConfigName $configName -TenantId $tenantId -AppId $appId -AuthMethod $authMethod -CertThumbprint $certThumbprint) {
            Write-IntuneToolkitLog "Configuration '$configName' saved successfully" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            # Refresh ComboBox
            $savedConfigs = Get-SavedTenantConfigs
            $SavedTenantsComboBox.Items.Clear()
            foreach ($config in $savedConfigs) {
                [void]$SavedTenantsComboBox.Items.Add($config)
            }
            $SavedTenantsComboBox.SelectedItem = $configName
            Write-IntuneToolkitLog "ComboBox refreshed with $($savedConfigs.Count) configurations" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            [System.Windows.MessageBox]::Show("Configuration saved successfully as '$configName'.", "Success", "OK", "Information")
        }
        else {
            Write-IntuneToolkitLog "Failed to save configuration '$configName'" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            [System.Windows.MessageBox]::Show("Failed to save configuration.", "Error", "OK", "Error")
        }
    })

    # Add event handlers for radio buttons to show/hide input panels
    $RadioButtonClientSecret.Add_Checked({
        $ClientSecretInputPanel.Visibility = "Visible"
        $CertificateInputPanel.Visibility = "Collapsed"
        $InteractiveInputPanel.Visibility = "Collapsed"
    })

    $RadioButtonCertificate.Add_Checked({
        $ClientSecretInputPanel.Visibility = "Collapsed"
        $CertificateInputPanel.Visibility = "Visible"
        $InteractiveInputPanel.Visibility = "Collapsed"
    })

    $RadioButtonInteractive.Add_Checked({
        $ClientSecretInputPanel.Visibility = "Collapsed"
        $CertificateInputPanel.Visibility = "Collapsed"
        $InteractiveInputPanel.Visibility = "Visible"
    })

    # Add Browse Certificate button handler
    $BrowseCertButton.Add_Click({
        Write-IntuneToolkitLog "Certificate browser button clicked" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
        
        try {
            # Get certificates from both CurrentUser and LocalMachine stores
            $certs = @()
            $certs += Get-ChildItem -Path Cert:\CurrentUser\My -ErrorAction SilentlyContinue | Where-Object { $_.HasPrivateKey }
            $certs += Get-ChildItem -Path Cert:\LocalMachine\My -ErrorAction SilentlyContinue | Where-Object { $_.HasPrivateKey }
            
            if ($certs.Count -eq 0) {
                Write-IntuneToolkitLog "No certificates with private keys found in certificate stores" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
                [System.Windows.MessageBox]::Show("No certificates with private keys found in your certificate stores (CurrentUser\My or LocalMachine\My).`n`nPlease install a certificate with a private key first.", "No Certificates Found", "OK", "Warning")
                return
            }
            
            Write-IntuneToolkitLog "Found $($certs.Count) certificates with private keys" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            
            # Create certificate selection objects with relevant info
            $certList = $certs | ForEach-Object {
                [PSCustomObject]@{
                    Subject = $_.Subject
                    Issuer = $_.Issuer
                    Thumbprint = $_.Thumbprint
                    NotAfter = $_.NotAfter
                    FriendlyName = if ($_.FriendlyName) { $_.FriendlyName } else { "(No friendly name)" }
                    Store = if ($_.PSPath -like "*CurrentUser*") { "CurrentUser" } else { "LocalMachine" }
                }
            }
            
            # Show selection dialog
            $selectedCert = $certList | Out-GridView -Title "Select Certificate for Authentication" -OutputMode Single
            
            if ($selectedCert) {
                $CertThumbprintTextBox.Text = $selectedCert.Thumbprint
                Write-IntuneToolkitLog "Certificate selected: $($selectedCert.Subject) (Thumbprint: $($selectedCert.Thumbprint))" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            }
            else {
                Write-IntuneToolkitLog "Certificate selection cancelled" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            }
        }
        catch {
            Write-IntuneToolkitLog "Error browsing certificates: $($_.Exception.Message)" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            [System.Windows.MessageBox]::Show("Error browsing certificates: $($_.Exception.Message)", "Error", "OK", "Error")
        }
    })

    # Define the click event handler for the Submit button
    $SubmitButton.Add_Click({
        Write-IntuneToolkitLog "Submit button clicked" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
        
        # Determine which authentication method is selected
        if ($RadioButtonClientSecret.IsChecked) {
            Write-IntuneToolkitLog "Client Secret authentication selected" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            
            # Retrieve values from the textboxes
            $TenantID = $TenantIDTextBox.Text
            $AppID = $AppIDTextBox.Text
            $AppSecret = $AppSecretTextBox.Password

            # Validate inputs
            if (-not $TenantID -or -not $AppID -or -not $AppSecret) {
                Write-IntuneToolkitLog "Failed: Missing input fields for Client Secret authentication" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
                $StatusText.Text = "Error: Please fill out all fields."
                return
            }

            Write-IntuneToolkitLog "User input collected: Tenant ID = $TenantID, App ID = $AppID" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"

            # Close the window
            $window.Close()

            # Log the connection attempt
            Write-IntuneToolkitLog "Attempting to connect using Client Secret - Tenant ID: $TenantID, App ID: $AppID" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            $StatusText.Text = "Connecting to Microsoft Graph..."

            try {
                # Use Connect-ToMgGraph with entraapp parameter
                $authParams = @{
                    entraapp = $true
                    AppId = $AppID
                    AppSecret = $AppSecret
                    Tenant = $TenantID
                    Scopes = @("User.Read.All", "Directory.Read.All", "DeviceManagementConfiguration.ReadWrite.All", "DeviceManagementApps.ReadWrite.All", "DeviceManagementScripts.ReadWrite.All")
                }

                .\Scripts\Connect-ToMgGraph.ps1 @authParams
                Write-IntuneToolkitLog "Successfully connected to Microsoft Graph with Client Secret" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            }
            catch {
                Write-IntuneToolkitLog "Error connecting with Client Secret: $($_.Exception.Message)" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
                $StatusText.Text = "Error: Failed to connect. Check logs."
                return
            }
        }
        elseif ($RadioButtonCertificate.IsChecked) {
            Write-IntuneToolkitLog "Certificate authentication selected" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            
            # Retrieve values
            $TenantID = $TenantIDTextBoxCert.Text
            $AppID = $AppIDTextBoxCert.Text
            $CertThumbprint = $CertThumbprintTextBox.Text

            # Validate inputs
            if (-not $TenantID -or -not $AppID -or -not $CertThumbprint) {
                Write-IntuneToolkitLog "Failed: Missing input fields for Certificate authentication" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
                $StatusText.Text = "Error: Please fill out all fields."
                return
            }

            # Validate certificate thumbprint format (40 hex characters)
            if ($CertThumbprint -notmatch '^[A-Fa-f0-9]{40}$') {
                Write-IntuneToolkitLog "Failed: Invalid certificate thumbprint format" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
                $StatusText.Text = "Error: Certificate thumbprint must be 40 hexadecimal characters."
                return
            }

            Write-IntuneToolkitLog "User input collected: Tenant ID = $TenantID, App ID = $AppID, Cert Thumbprint = $CertThumbprint" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"

            # Close the window
            $window.Close()

            # Log the connection attempt
            Write-IntuneToolkitLog "Attempting to connect using Certificate - Tenant ID: $TenantID, App ID: $AppID" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            $StatusText.Text = "Connecting to Microsoft Graph..."

            try {
                # Use Connect-ToMgGraph with usessl parameter
                $authParams = @{
                    usessl = $true
                    AppId = $AppID
                    TenantId = $TenantID
                    CertificateThumbprint = $CertThumbprint
                }

                .\Scripts\Connect-ToMgGraph.ps1 @authParams
                Write-IntuneToolkitLog "Successfully connected to Microsoft Graph with Certificate" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            }
            catch {
                Write-IntuneToolkitLog "Error connecting with Certificate: $($_.Exception.Message)" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
                $StatusText.Text = "Error: Failed to connect. Check certificate and logs."
                return
            }
        }
        elseif ($RadioButtonInteractive.IsChecked) {
            Write-IntuneToolkitLog "Interactive authentication selected" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            
            # Retrieve values
            $TenantID = $TenantIDTextBoxInt.Text
            $AppID = $AppIDTextBoxInt.Text
            $ScopesText = $ScopesTextBox.Text

            # Parse scopes (comma or semicolon separated)
            if ([string]::IsNullOrWhiteSpace($ScopesText)) {
                $Scopes = @("User.Read.All", "Directory.Read.All", "DeviceManagementConfiguration.ReadWrite.All", "DeviceManagementApps.ReadWrite.All", "DeviceManagementScripts.ReadWrite.All")
                Write-IntuneToolkitLog "Using default scopes for Interactive authentication" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            }
            else {
                $Scopes = $ScopesText -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                Write-IntuneToolkitLog "Using custom scopes: $($Scopes -join ', ')" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            }

            Write-IntuneToolkitLog "User input collected: Tenant ID = $TenantID, App ID = $AppID (empty means default), Scopes count = $($Scopes.Count)" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"

            # Close the window
            $window.Close()

            # Log the connection attempt
            Write-IntuneToolkitLog "Attempting to connect using Interactive authentication" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            $StatusText.Text = "Connecting to Microsoft Graph (Interactive)..."

            try {
                # Use Connect-ToMgGraph with interactive parameter
                $authParams = @{
                    interactive = $true
                    Scopes = $Scopes
                }

                # Add TenantId if provided (required for single-tenant apps)
                if (-not [string]::IsNullOrWhiteSpace($TenantID)) {
                    $authParams['TenantId'] = $TenantID
                    Write-IntuneToolkitLog "Using Tenant ID: $TenantID" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
                }

                # Add AppId if provided
                if (-not [string]::IsNullOrWhiteSpace($AppID)) {
                    $authParams['AppId'] = $AppID
                    Write-IntuneToolkitLog "Using custom App ID: $AppID" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
                }

                .\Scripts\Connect-ToMgGraph.ps1 @authParams
                Write-IntuneToolkitLog "Successfully connected to Microsoft Graph with Interactive authentication" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            }
            catch {
                Write-IntuneToolkitLog "Error connecting with Interactive authentication: $($_.Exception.Message)" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
                $StatusText.Text = "Error: Failed to connect. Check logs."
                return
            }
        }

        # Update UI elements after successful connection (common for all authentication methods)
        try {
            Write-IntuneToolkitLog "Updating UI elements after successful connection" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"

            # Update UI elements
            $StatusText.Text = "Please select a policy type."
            $PolicyDataGrid.Visibility = "Visible"
            $RenameButton.IsEnabled = $true
            $DeleteAssignmentButton.IsEnabled = $true
            $AddAssignmentButton.IsEnabled = $true
            $BackupButton.IsEnabled = $true
            $RestoreButton.IsEnabled = $true
            $ConfigurationPoliciesButton.IsEnabled = $true
            $GlobalGroupSearchButton.IsEnabled = $true
            $DeviceConfigurationButton.IsEnabled = $true
            $ComplianceButton.IsEnabled = $true
            $AdminTemplatesButton.IsEnabled = $true
            $ApplicationsButton.IsEnabled = $true
            $AppConfigButton.IsEnabled = $true
            $MacosScriptsButton.IsEnabled = $true
            $IntentsButton.IsEnabled = $true
            $RemediationScriptsButton.IsEnabled = $true
            $PlatformScriptsButton.IsEnabled = $true
            $ConnectButton.IsEnabled = $false
            $ConnectEnterpriseAppButton.IsEnabled = $false
            $LogoutButton.IsEnabled = $true
            $RefreshButton.IsEnabled = $true
            $SearchFieldComboBox.IsEnabled = $true
            $SearchBox.IsEnabled = $true
            $SearchButton.IsEnabled = $true
            $AssignmentReportButton.IsEnabled = $true
            $DeviceCustomAttributeShellScriptsButton.IsEnabled = $true
            $AutopilotProfilesButton.IsEnabled = $true
            $AddFilterButton.IsEnabled = $true

            # Fetch and display tenant information
            $tenant = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/organization" -Method GET
            $context = Get-MgContext
            $appInfo = if ($context.AppName) { "$($context.AppName) ($($context.ClientId))" } else { $context.ClientId }
            
            # Check if this is app-only authentication (Client Secret or Certificate) or delegated (Interactive)
            # App-only auth won't have access to /me endpoint
            if ($context.AuthType -eq 'AppOnly') {
                # App-only authentication - no user context
                $TenantInfo.Text = "Tenant: $($tenant.value[0].displayName) | Auth: Application (App-Only)`nApp: $appInfo"
                Write-IntuneToolkitLog "Connected with app-only authentication" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            }
            else {
                # Delegated authentication - has user context
                try {
                    $user = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/me" -Method GET
                    $TenantInfo.Text = "Tenant: $($tenant.value[0].displayName) | User: $($user.userPrincipalName)`nApp: $appInfo"
                    Write-IntuneToolkitLog "Connected with delegated authentication - User: $($user.userPrincipalName)" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
                }
                catch {
                    # Fallback if /me call fails
                    $TenantInfo.Text = "Tenant: $($tenant.value[0].displayName) | Auth: Application (App-Only)`nApp: $appInfo"
                    Write-IntuneToolkitLog "Could not fetch user info, treating as app-only auth" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
                }
            }

            # Fetch security groups
            Write-IntuneToolkitLog "Fetching security groups" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            $global:AllSecurityGroups = Get-AllSecurityGroups
            Write-IntuneToolkitLog "Successfully fetched security groups" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
        }
        catch {
            Write-IntuneToolkitLog "Error updating UI after connection: $($_.Exception.Message)" -component "ConnectEnterpriseAppButton" -file "ConnectEnterpriseAppButton.ps1"
            $StatusText.Text = "Connected, but error loading tenant info."
        }
    })
    Set-WindowIcon -Window $Window
    # Show the popup window
    $window.ShowDialog()
})
