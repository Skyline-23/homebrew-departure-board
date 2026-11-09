using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
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
        Margin = new Thickness(0, 12, 0, 0),
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
        Width = 640;
        Height = Math.Min(940, SystemParameters.WorkArea.Height - 50);
        ResizeMode = ResizeMode.CanMinimize;
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Background = Brushes.White;
        FontFamily = new FontFamily("Segoe UI");
        FontSize = 14;
        var panel = new StackPanel { Margin = new Thickness(28) };
        panel.Children.Add(
            new TextBlock
            {
                Text = "Departure Board",
                FontSize = 26,
                FontWeight = FontWeights.SemiBold,
                Margin = new Thickness(0, 0, 0, 20),
            }
        );
        Content = new ScrollViewer
        {
            Content = panel,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
        };
        Populate();
        AddRow(panel, "Airport", airport);
        AddRow(panel, "Language", language);
        AddRow(panel, "Board style", style);
        AddRow(panel, "Timetable source", source);
        AddRow(panel, "API key", apiKey);
        AddRow(panel, "Data refresh", refresh);
        AddRow(
            panel,
            "Provider",
            new TextBox
            {
                Text = "AeroDataBox · RapidAPI",
                IsReadOnly = true,
                BorderThickness = new Thickness(0),
            }
        );
        panel.Children.Add(dataStatus);
        AddRow(panel, "Row density", density);
        AddRow(panel, "Board scale", scale);
        AddRow(panel, "Brightness", brightness);
        panel.Children.Add(reduceMotion);
        panel.Children.Add(wallpaper);
        panel.Children.Add(allDesktops);
        panel.Children.Add(startup);
        panel.Children.Add(Buttons());
        panel.Children.Add(status);
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

    private UIElement Buttons()
    {

        var panel = new WrapPanel
        {
            Orientation = Orientation.Horizontal,
            Margin = new Thickness(0, 22, 0, 0),
        };
        var save = new Button { Content = "Apply", Padding = new Thickness(18, 7, 18, 7) };
        save.Click += (_, _) => Save();
        panel.Children.Add(save);
        var show = new Button
        {
            Content = "Preview",
            Margin = new Thickness(10, 0, 0, 0),
            Padding = new Thickness(12, 7, 12, 7),
        };
        show.Click += (_, _) => preview();
        panel.Children.Add(show);
        var install = new Button
        {
            Content = "Set as screen saver",
            Margin = new Thickness(10, 0, 0, 0),
            Padding = new Thickness(12, 7, 12, 7),
        };
        install.Click += (_, _) => RegisterScreenSaver();
        panel.Children.Add(install);
        var still = new Button
        {
            Content = "Set as wallpaper",
            Margin = new Thickness(10, 8, 0, 0),
            Padding = new Thickness(12, 7, 12, 7),
        };
        still.Click += (_, _) => SetStillWallpaper();
        panel.Children.Add(still);
        return panel;
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

        var row = new Grid { Margin = new Thickness(0, 0, 0, 14) };
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(130) });
        row.ColumnDefinitions.Add(new ColumnDefinition());
        row.Children.Add(
            new TextBlock { Text = label, VerticalAlignment = VerticalAlignment.Center }
        );
        control.MinHeight = 30;
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
