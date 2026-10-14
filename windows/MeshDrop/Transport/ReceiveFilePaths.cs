using System;
using System.IO;
using System.Linq;

namespace MeshDrop.Transport;

internal static class ReceiveFilePaths
{
    // Peer names and filenames arrive over the network; keep them to one Windows path segment.
    internal static string SafeSegment(string value, string fallback)
    {
        var invalid = "<>:\"/\\|?*";
        var clean = new string((value ?? "").Select(c => c < 32 || invalid.Contains(c) ? '_' : c).ToArray())
            .Trim().TrimEnd('.');
        if (clean.Length > 120) clean = clean[..120].TrimEnd('.', ' ');
        if (string.IsNullOrEmpty(clean)) return fallback;
        var stem = clean.Split('.')[0].TrimEnd(' ');
        if (stem.Equals("CON", StringComparison.OrdinalIgnoreCase)
            || stem.Equals("PRN", StringComparison.OrdinalIgnoreCase)
            || stem.Equals("AUX", StringComparison.OrdinalIgnoreCase)
            || stem.Equals("NUL", StringComparison.OrdinalIgnoreCase)
            || (stem.Length == 4 && (stem.StartsWith("COM", StringComparison.OrdinalIgnoreCase)
                || stem.StartsWith("LPT", StringComparison.OrdinalIgnoreCase)) && char.IsDigit(stem[3])))
            clean = "_" + clean;
        return clean;
    }

    internal static string DirectoryFor(string documents, string peerName) =>
        Path.Combine(documents, "MeshDrop", SafeSegment(peerName, "Device"));

    internal static string AvailableFile(string directory, string fileName)
    {
        fileName = SafeSegment(fileName, "Received file");
        var path = Path.Combine(directory, fileName);
        var name = Path.GetFileNameWithoutExtension(fileName);
        var ext = Path.GetExtension(fileName);
        for (var n = 1; File.Exists(path) || Directory.Exists(path); n++)
            path = Path.Combine(directory, $"{name} ({n}){ext}");
        return path;
    }
}
