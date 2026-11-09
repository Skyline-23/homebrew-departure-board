using System;
using System.IO;
using System.Threading;
using System.Windows;
using DepartureBoard.Core.Runtime;
using DepartureBoard.Windows.Platform;

namespace DepartureBoard.Windows;

internal static class Program
{
    [STAThread]
    private static int Main(string[] arguments)
    {
        var selfTest = arguments.Length > 0 && arguments[0] == "--self-test";

        try
        {
            var options = LaunchOptions.Parse(arguments);
            var application = new Application { ShutdownMode = ShutdownMode.OnExplicitShutdown };

            if (options.Mode == LaunchMode.SelfTest)
            {
                return WindowsSmokeTest.Run(arguments.Length > 1 ? arguments[1] : "smoke-output");
            }

            using var services = new AppServices();

            if (options.Mode is LaunchMode.ScreenSaver or LaunchMode.Preview)
            {
                var displays = new DisplayWindows(services);

                if (options.Mode == LaunchMode.Preview)
                {
                    displays.ShowPreview(options.PreviewParent);
                }
                else
                {
                    displays.ShowScreenSaver();
                }

                return application.Run();
            }

            using var signal = new EventWaitHandle(
                false,
                EventResetMode.AutoReset,
                "Local\\DepartureBoard.ShowSettings"
            );
            using var mutex = new Mutex(
                true,
                "Local\\com.skyline23.departureboard",
                out var firstInstance
            );

            if (!firstInstance)
            {
                signal.Set();
                return 0;
            }

            using var tray = new TrayApplication(services);

            if (options.Mode == LaunchMode.Settings)
            {
                tray.ShowSettings();
            }

            return application.Run();
        }
        catch (Exception error)
        {
            if (selfTest)
            {
                var directory = arguments.Length > 1 ? arguments[1] : "smoke-output";
                Directory.CreateDirectory(directory);
                File.WriteAllText(Path.Combine(directory, "failure.txt"), error.ToString());
                Console.Error.WriteLine(error);
                return 1;
            }

            MessageBox.Show(
                error.Message,
                "Departure Board",
                MessageBoxButton.OK,
                MessageBoxImage.Error
            );
            return 1;
        }
    }
}
