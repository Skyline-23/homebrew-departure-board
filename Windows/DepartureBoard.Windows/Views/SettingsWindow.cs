using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using DepartureBoard.Core.Airports;
using DepartureBoard.Core.Settings;
using DepartureBoard.Windows.Platform;

namespace DepartureBoard.Windows.Views;

internal sealed class SettingsWindow : Window
{
    private const string SavedKeyMask = "••••••••••••";
    private readonly AppServices services;
    private readonly ComboBox airport = new();
    private readonly ComboBox language = new();
    private readonly ComboBox style = new();
    private readonly ComboBox source = new();
    private readonly ComboBox refresh = new();
    private readonly ComboBox density = new();
    private readonly PasswordBox apiKey = new();
    private readonly ComboBox scale = new();
    private readonly Slider brightness = new()
    {
        Minimum = 0.35,
        Maximum = 1,
        TickFrequency = 0.05,
        IsSnapToTickEnabled = true,
    };
    private readonly CheckBox reduceMotion = new() { Content = "Reduce motion" };
    private readonly CheckBox allDesktops = new() { Content = "Show on all desktops" };
    private readonly CheckBox wallpaper = new() { Content = "Live desktop wallpaper" };
    private readonly CheckBox startup = new() { Content = "Launch in background at sign-in" };
    private readonly TextBlock status = new()
    {
        TextWrapping = TextWrapping.Wrap,
        Margin = new Thickness(0, 16, 0, 0),
        Foreground = SystemColors.GrayTextBrush,
        FontSize = 12,
    };
    private readonly Action preview;
    private readonly Func<bool> applyWallpaper;
    private readonly TextBlock dataStatus = new() { TextWrapping = TextWrapping.Wrap };

    public SettingsWindow(AppServices services, Action preview, Func<bool> applyWallpaper)
    {

        this.services = services;
        this.preview = preview;
        this.applyWallpaper = applyWallpaper;
        Title = "Departure Board Settings";
        Width = Math.Min(760, SystemParameters.WorkArea.Width - 48);
        Height = Math.Min(860, SystemParameters.WorkArea.Height - 48);
        MinWidth = 560;
        MinHeight = 420;
        ResizeMode = ResizeMode.CanResize;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Background = new SolidColorBrush(Color.FromRgb(246, 247, 249));
        FontFamily = new FontFamily("Segoe UI Variable Text, Segoe UI");
        FontSize = 14;
        Resources.MergedDictionaries.Add(
            new ResourceDictionary
            {
                Source = new Uri(
                    "pack://application:,,,/PresentationFramework.Fluent;component/Themes/Fluent.Light.xaml"
                ),
            }
        );
        var layout = new Grid { Background = Background };
        layout.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        layout.RowDefinitions.Add(
            new RowDefinition { Height = new GridLength(1, GridUnitType.Star) }
        );
        layout.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        Content = layout;
        layout.Children.Add(Header());
        var panel = new StackPanel { Margin = new Thickness(24, 0, 24, 24) };
        var scroll = new ScrollViewer
        {
            Content = panel,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
            Padding = new Thickness(0, 0, 4, 0),
        };
        Grid.SetRow(scroll, 1);
        layout.Children.Add(scroll);
        Populate();

        var display = Section(panel, "Display", "Choose the airport and how the board looks.");
        AddRow(display, "Airport", airport);
        AddRow(display, "Language", language);
        AddRow(display, "Board style", style);
        AddRow(display, "Rows", density);
        AddRow(display, "Scale", scale);
        AddRow(display, "Brightness", brightness);
        AddRow(display, "Animation", reduceMotion);

        var desktop = Section(panel, "Desktop", "Make it part of your workspace.");
        AddOption(desktop, wallpaper);
        AddOption(desktop, allDesktops);
        AddOption(desktop, startup);
        var desktopActions = new WrapPanel { Margin = new Thickness(0, 8, 0, 0) };
        var still = ActionButton("Set as wallpaper");
        still.Click += (_, _) => SetStillWallpaper();
        desktopActions.Children.Add(still);
        var saver = ActionButton("Set as screen saver");
        saver.Margin = new Thickness(10, 0, 0, 0);
        saver.Click += (_, _) => RegisterScreenSaver();
        desktopActions.Children.Add(saver);
        desktop.Children.Add(desktopActions);

        var data = Section(
            panel,
            "Flight data",
            "Try the sample schedule or connect your own account."
        );
        AddRow(data, "Timetable", source);
        AddRow(data, "API key", apiKey);
        AddRow(data, "Refresh", refresh);
        data.Children.Add(
            new TextBlock
            {
                Text = "AeroDataBox · RapidAPI",
                Foreground = SystemColors.GrayTextBrush,
                FontSize = 12,
                Margin = new Thickness(0, 4, 0, 6),
            }
        );
        dataStatus.FontSize = 12;
        dataStatus.Foreground = SystemColors.GrayTextBrush;
        data.Children.Add(dataStatus);

        var footer = Footer();
        Grid.SetRow(footer, 2);
        layout.Children.Add(footer);
        status.Text = services.HasApiKey
            ? "API key saved in Windows Credential Manager."
            : "Use sample mode or enter your AeroDataBox RapidAPI key.";
        UpdateDataStatus();
        services.DataChanged += OnDataChanged;
        Closed += (_, _) => services.DataChanged -= OnDataChanged;
    }

    public int AirportCount => airport.Items.Count;

    private void Populate()
    {

        var settings = services.Settings;

        foreach (var profile in services.Catalog.Airports)
        {
            var label = services.Catalog.Strings.Get(profile.Data.Text("displayNameKey"));
            airport.Items.Add(new Choice(profile.Code, label));
        }

        SetChoices(
            language,
            [
                new("alternate", "English and local language"),
                new("english", "English"),
                new("native", "Local language"),
            ]
        );
        SetChoices(
            style,
            [new("auto", "Automatic"), new("lcd", "LCD display"), new("flap", "Split-flap display")]
        );
        SetChoices(
            source,
            [
                new("sample", "Sample schedule · visual preview only"),
                new("live", "Live flight data"),
            ]
        );
        SetChoices(
            refresh,
            [
                new("60", "1 minute"),
                new("300", "5 minutes"),
                new("900", "15 minutes"),
                new("3600", "1 hour"),
                new("21600", "6 hours"),
            ]
        );
        SetChoices(
            density,
            [
                new("0", "Airport layout"),
                new("10", "10 rows"),
                new("12", "12 rows"),
                new("16", "16 rows"),
            ]
        );
        SetChoices(
            scale,
            [
                new("0.5", "50%"),
                new("0.65", "65%"),
                new("0.75", "75%"),
                new("0.85", "85%"),
                new("1", "100%"),
            ]
        );
        Select(airport, settings.Airport);
        Select(language, settings.Language);
        Select(style, settings.Style);
        Select(source, settings.SampleData ? "sample" : "live");
        Select(
            refresh,
            settings.RefreshSeconds.ToString(System.Globalization.CultureInfo.InvariantCulture)
        );
        Select(
            density,
            settings.Density.ToString(System.Globalization.CultureInfo.InvariantCulture)
        );
        apiKey.Password = services.HasApiKey ? SavedKeyMask : "";
        Select(scale, settings.Scale.ToString(System.Globalization.CultureInfo.InvariantCulture));
        brightness.Value = settings.Brightness;
        reduceMotion.IsChecked = settings.ReduceMotion;
        allDesktops.IsChecked = settings.ShowAllDesktops;
        wallpaper.IsChecked = settings.WallpaperEnabled;
        startup.IsChecked = settings.LaunchAtLogin;
    }

    private static UIElement Header()
    {

        var header = new Grid { Margin = new Thickness(28, 24, 28, 22) };
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        header.ColumnDefinitions.Add(new ColumnDefinition());
        var icon = new Image
        {
            Width = 44,
            Height = 44,
            Margin = new Thickness(0, 0, 14, 0),
            Source = new BitmapImage(
                new Uri(Path.Combine(AppContext.BaseDirectory, "Assets", "DepartureBoard.ico"))
            ),
        };
        header.Children.Add(icon);
        var title = new StackPanel();
        Grid.SetColumn(title, 1);
        title.Children.Add(
            new TextBlock
            {
                Text = "Departure Board",
                FontSize = 24,
                FontWeight = FontWeights.SemiBold,
            }
        );
        title.Children.Add(
            new TextBlock
            {
                Text = "Wallpaper and screen saver",
                Foreground = SystemColors.GrayTextBrush,
                Margin = new Thickness(0, 2, 0, 0),
            }
        );
        header.Children.Add(title);
        return header;
    }

    private UIElement Footer()
    {

        var panel = new StackPanel { Margin = new Thickness(24, 12, 24, 20) };
        status.Margin = new Thickness(0, 0, 0, 12);
        panel.Children.Add(status);
        var actions = new DockPanel { LastChildFill = false };
        var guide = ActionButton("Installation guide");
        guide.Click += (_, _) => InstallationGuide.Open();
        DockPanel.SetDock(guide, Dock.Left);
        actions.Children.Add(guide);
        var save = ActionButton("Apply changes");
        save.IsDefault = true;
        save.Background = new SolidColorBrush(Color.FromRgb(0, 95, 184));
        save.Foreground = Brushes.White;
        save.BorderThickness = new Thickness(0);
        save.Click += (_, _) => Save();
        DockPanel.SetDock(save, Dock.Right);
        actions.Children.Add(save);
        var show = ActionButton("Preview");
        show.Margin = new Thickness(0, 0, 10, 0);
        show.Click += (_, _) => preview();
        DockPanel.SetDock(show, Dock.Right);
        actions.Children.Add(show);
        panel.Children.Add(actions);
        return new Border
        {
            Background = Brushes.White,
            BorderBrush = new SolidColorBrush(Color.FromRgb(225, 228, 232)),
            BorderThickness = new Thickness(0, 1, 0, 0),
            Child = panel,
        };
    }

    private static Button ActionButton(string title)
    {

        return new Button
        {
            Content = title,
            MinHeight = 36,
            Padding = new Thickness(16, 8, 16, 8),
        };
    }

    private static StackPanel Section(Panel parent, string title, string description)
    {

        var content = new StackPanel { Margin = new Thickness(20, 18, 20, 12) };
        content.Children.Add(
            new TextBlock
            {
                Text = title,
                FontSize = 17,
                FontWeight = FontWeights.SemiBold,
            }
        );
        content.Children.Add(
            new TextBlock
            {
                Text = description,
                FontSize = 12,
                Foreground = SystemColors.GrayTextBrush,
                TextWrapping = TextWrapping.Wrap,
                Margin = new Thickness(0, 4, 0, 18),
            }
        );
        parent.Children.Add(
            new Border
            {
                Background = Brushes.White,
                BorderBrush = new SolidColorBrush(Color.FromRgb(225, 228, 232)),
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(10),
                Margin = new Thickness(0, 0, 0, 14),
                Child = content,
            }
        );
        return content;
    }

    private static void AddOption(Panel panel, CheckBox option)
    {

        option.MinHeight = 36;
        option.Margin = new Thickness(0, 0, 0, 6);
        panel.Children.Add(option);
    }

    private bool Save()
    {

        try
        {
            var settings = services.Settings with
            {
                Airport = Value(airport),
                Language = Value(language),
                Style = Value(style),
                SampleData = Value(source) == "sample",
                Scale = double.Parse(
                    Value(scale),
                    System.Globalization.CultureInfo.InvariantCulture
                ),
                Brightness = brightness.Value,
                ReduceMotion = reduceMotion.IsChecked == true,
                ShowAllDesktops = allDesktops.IsChecked == true,
                Density = int.Parse(
                    Value(density),
                    System.Globalization.CultureInfo.InvariantCulture
                ),
                RefreshSeconds = int.Parse(
                    Value(refresh),
                    System.Globalization.CultureInfo.InvariantCulture
                ),
                WallpaperEnabled = wallpaper.IsChecked == true,
                LaunchAtLogin = startup.IsChecked == true,
            };
            services.Save(settings, apiKey.Password == SavedKeyMask ? "" : apiKey.Password);
            status.Text = applyWallpaper()
                ? "Settings saved."
                : "Settings saved. Windows Explorer's desktop host is unavailable.";
            apiKey.Password = services.HasApiKey ? SavedKeyMask : "";
            UpdateDataStatus();
            return true;
        }
        catch (Exception error)
            when (error is ArgumentException or IOException or System.ComponentModel.Win32Exception)
        {
            status.Text = error.Message;
            return false;
        }
    }

    private void UpdateDataStatus()
    {

        var snapshot = services.Flights.Read(services.Settings.Airport);
        dataStatus.Text =
            services.Flights.LastError
            ?? (
                snapshot is null
                    ? "Last update: never"
                    : "Last update: "
                        + services
                            .Catalog.Get(services.Settings.Airport)
                            .LocalTime(snapshot.FetchedAt)
                            .ToString("g")
            );
    }

    private void OnDataChanged(object? sender, EventArgs arguments)
    {

        UpdateDataStatus();
    }

    private void SetStillWallpaper()
    {

        if (!Save())
        {
            return;
        }

        try
        {
            WallpaperSnapshot.Apply(services);
            status.Text = services.Settings.WallpaperEnabled
                ? "Wallpaper applied. Live wallpaper remains enabled."
                : "Wallpaper applied. Enable Live desktop wallpaper for automatic updates.";
        }
        catch (Exception error) when (error is IOException or System.ComponentModel.Win32Exception)
        {
            status.Text = error.Message;
        }
    }

    private void RegisterScreenSaver()
    {

        try
        {
            ScreenSaverRegistration.Register();
            status.Text = "Departure Board is now your screen saver.";
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        {
            status.Text = error.Message;
        }
    }

    private static void AddRow(Panel panel, string label, Control control)
    {

        var row = new Grid { Margin = new Thickness(0, 0, 0, 12) };
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(146) });
        row.ColumnDefinitions.Add(new ColumnDefinition());
        row.Children.Add(
            new TextBlock
            {
                Text = label,
                VerticalAlignment = VerticalAlignment.Center,
                Foreground = SystemColors.GrayTextBrush,
            }
        );
        control.MinHeight = 36;
        control.FontSize = 14;
        AutomationProperties.SetName(control, label);
        Grid.SetColumn(control, 1);
        row.Children.Add(control);
        panel.Children.Add(row);
    }

    private static void SetChoices(ItemsControl control, IEnumerable<Choice> choices)
    {

        foreach (var choice in choices)
        {
            control.Items.Add(choice);
        }
    }

    private static void Select(ComboBox control, string value)
    {

        control.SelectedItem =
            control.Items.Cast<Choice>().FirstOrDefault(item => item.Value == value)
            ?? control.Items.Cast<Choice>().FirstOrDefault();
    }

    private static string Value(ComboBox control)
    {

        return (control.SelectedItem as Choice)?.Value
            ?? throw new ArgumentException("Select an option for every field.");
    }

    private sealed record Choice(string Value, string Label)
    {
        public override string ToString() => Label;
    }
}
