<#
.SYNOPSIS
Displays a simple dialog to select a Security Group.

.DESCRIPTION
This function creates a modal dialog allowing the user to pick a security group from the global list.
It returns the selected group object (Id, DisplayName) or $null if canceled.

.NOTES
Author: Intune Toolkit
#>
function Show-GroupSearchDialog {
    param(
        [Parameter(Mandatory=$true)]
        [array]$AllGroups
    )

    # Define minimal XAML for the dialog
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Select Group to Search" Height="200" Width="400" 
        WindowStartupLocation="CenterScreen" Topmost="True" ResizeMode="NoResize" WindowStyle="ToolWindow" Background="#f3f3f3">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#007ACC"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="3">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <TextBlock Text="Search for a Security Group:" FontWeight="Bold" Margin="0,0,0,5"/>
        <TextBox x:Name="SearchBox" Grid.Row="1" Margin="0,0,0,10" Height="25"/>
        <ComboBox x:Name="GroupComboBox" Grid.Row="2" Height="30" VerticalAlignment="Top"  DisplayMemberPath="DisplayName"/>
        
        <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="SearchBtn" Content="Search" Width="80" IsDefault="True"/>
            <Button x:Name="CancelBtn" Content="Cancel" Width="80" IsCancel="True"/>
        </StackPanel>
    </Grid>
</Window>
"@

    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
    $window = [Windows.Markup.XamlReader]::Load($reader)

    # Controls
    $searchBox = $window.FindName("SearchBox")
    $comboBox = $window.FindName("GroupComboBox")
    $searchBtn = $window.FindName("SearchBtn")
    $cancelBtn = $window.FindName("CancelBtn")

    # Populate ComboBox
    $comboBox.ItemsSource = $AllGroups
    
    # Logic variables
    $script:selectedGroup = $null

    # Search Box Logic (Live Filter)
    $searchBox.Add_TextChanged({
        $filterText = $searchBox.Text
        if ([string]::IsNullOrWhiteSpace($filterText)) {
            $comboBox.ItemsSource = $AllGroups
        } else {
            $comboBox.ItemsSource = $AllGroups | Where-Object { $_.DisplayName -like "*$filterText*" }
        }
        if ($comboBox.Items.Count -gt 0) {
            $comboBox.SelectedIndex = 0
        }
    })

    # Search Button
    $searchBtn.Add_Click({
        if ($comboBox.SelectedItem) {
            $script:selectedGroup = $comboBox.SelectedItem
            $window.DialogResult = $true
            $window.Close()
        } else {
            [System.Windows.Forms.MessageBox]::Show("Please select a group first.", "Warning", "OK", "Warning")
        }
    })

    $window.ShowDialog() | Out-Null
    return $script:selectedGroup
}
