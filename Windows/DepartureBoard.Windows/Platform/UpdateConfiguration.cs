using Microsoft.Win32;
using NetSparkleUpdater.AssemblyAccessors;
using NetSparkleUpdater.Configurations;

namespace DepartureBoard.Windows.Platform;

internal sealed class UpdateConfiguration : RegistryConfiguration
{
    public UpdateConfiguration(string? registryPath = null)
        : base(
            new AssemblyDiagnosticsAccessor(typeof(UpdateConfiguration).Assembly.Location),
            registryPath ?? @"Software\Skyline23\Departure Board\Updates"
        )
    {

        Reload();
    }

    public bool AutomaticUpdates { get; private set; }

    public override void Reload()
    {
        base.Reload();
        using var key = Registry.CurrentUser.OpenSubKey(BuildRegistryPath());
        // NetSparkle intentionally resets its legacy CheckForUpdate value to
        // true when saving. Keep the user's choice in our own persistent value.
        CheckForUpdate = key?.GetValue("AutomaticChecks", 1) is not int checks || checks != 0;
        AutomaticUpdates = key?.GetValue("AutomaticUpdates") is int value && value == 1;
    }

    public void SaveOptions(bool checks, bool automaticUpdates)
    {

        using var key = Registry.CurrentUser.CreateSubKey(BuildRegistryPath());
        key.SetValue("AutomaticChecks", checks ? 1 : 0, RegistryValueKind.DWord);
        key.SetValue("AutomaticUpdates", automaticUpdates ? 1 : 0, RegistryValueKind.DWord);
        CheckForUpdate = checks;
        AutomaticUpdates = automaticUpdates;
        TouchProfileTime();
    }
}
