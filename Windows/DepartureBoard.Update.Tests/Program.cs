using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using NetSparkleUpdater.AppCastHandlers;
using NetSparkleUpdater.Enums;
using NetSparkleUpdater.Interfaces;
using NetSparkleUpdater.SignatureVerifiers;

var directory = Path.GetFullPath(args[0]);
var publicKey = File.ReadAllText(Path.Combine(directory, "Resources/Updates/public-key.txt"))
    .Trim();

foreach (var platform in new[] { "windows-x64", "windows-arm64" })
{
    var checker = new Ed25519Checker(SecurityMode.Strict, publicKey);
    var filename = Path.Combine(directory, $"appcast-{platform}.xml");
    var data = File.ReadAllText(filename);
    var signature = File.ReadAllText(filename + ".signature");
    var helper = new AppCastHelper();
    helper.SetupAppCastHelper(
        new FixtureDownloader(data, signature),
        "https://fixture.test/appcast.xml",
        "1.2.2",
        checker
    );

    if (await helper.DownloadAppCast() != data)
        throw new Exception("Signed feed was rejected.");
    var items = new XMLAppCastGenerator().DeserializeAppCast(data).Items;
    var update = items.Single();

    if (AppCastReducers.RemoveOlderVersions(SemVerLike.Parse("1.2.2"), items).Count() != 1)
        throw new Exception("New version was not offered.");

    if (AppCastReducers.RemoveOlderVersions(SemVerLike.Parse("1.2.3"), items).Any())
        throw new Exception("Current version was offered again.");

    if (AppCastReducers.RemoveOlderVersions(SemVerLike.Parse("2.0.0"), items).Any())
        throw new Exception("Downgrade was offered.");
    var payload = File.ReadAllBytes(Path.Combine(directory, $"{platform}.bin"));
    var downloadSignature =
        update.DownloadSignature ?? throw new Exception("Missing installer signature.");

    if (checker.VerifySignature(downloadSignature, payload) != ValidationResult.Valid)
        throw new Exception("Installer signature was rejected.");
    payload[0] ^= 1;

    if (checker.VerifySignature(downloadSignature, payload) != ValidationResult.Invalid)
        throw new Exception("Tampered installer was accepted.");
    helper.SetupAppCastHelper(
        new FixtureDownloader(data.Replace("1.2.3", "9.9.9"), signature),
        "https://fixture.test/appcast.xml",
        "1.2.2",
        checker
    );

    if (await helper.DownloadAppCast() is not null)
        throw new Exception("Tampered feed was accepted.");
    helper.SetupAppCastHelper(
        new FixtureDownloader(data, ""),
        "https://fixture.test/appcast.xml",
        "1.2.2",
        checker
    );

    if (await helper.DownloadAppCast() is not null)
        throw new Exception("Unsigned feed was accepted.");
    Console.WriteLine(
        $"PASS {platform}: signatures, tampering, missing signature, current version and downgrade."
    );
}

internal sealed class FixtureDownloader(string data, string signature) : IAppCastDataDownloader
{
    public string DownloadAndGetAppCastData(string url) =>
        url.EndsWith(".signature", StringComparison.Ordinal) ? signature
        : url.EndsWith(".dsa", StringComparison.Ordinal) ? ""
        : data;

    public Task<string> DownloadAndGetAppCastDataAsync(string url) =>
        Task.FromResult(DownloadAndGetAppCastData(url));

    public Encoding GetAppCastEncoding() => Encoding.UTF8;
}
