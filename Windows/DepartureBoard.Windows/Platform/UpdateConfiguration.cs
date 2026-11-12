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
        AutomaticUpdates = key?.GetValue("AutomaticUpdates") is int value && value == 1;
    }

    public void SaveOptions(bool checks, bool automaticUpdates)
    {

        using var key = Registry.CurrentUser.CreateSubKey(BuildRegistryPath());
        key.SetValue("AutomaticUpdates", automaticUpdates ? 1 : 0, RegistryValueKind.DWord);
        CheckForUpdate = checks;
        AutomaticUpdates = automaticUpdates;
        TouchProfileTime();
    }
}
