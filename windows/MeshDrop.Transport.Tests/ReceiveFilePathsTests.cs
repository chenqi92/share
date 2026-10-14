using MeshDrop.Transport;
using Xunit;

public class ReceiveFilePathsTests
{
    [Theory]
    [InlineData("../outside.jpg")]
    [InlineData("..\\outside.jpg")]
    [InlineData("C:\\outside.jpg")]
    [InlineData("photo.jpg:stream")]
    [InlineData("CON.jpg")]
    [InlineData("..")]
    public void NetworkNamesStayWithinReceiveFolder(string name)
    {
        var root = Path.GetFullPath(Path.Combine(Path.GetTempPath(), "meshdrop-path-tests"));
        var directory = ReceiveFilePaths.DirectoryFor(root, name);
        var path = ReceiveFilePaths.AvailableFile(directory, name);
        Assert.Equal(directory, Path.GetDirectoryName(path));
        Assert.Equal(Path.Combine(root, "MeshDrop"), Path.GetDirectoryName(directory));
        Assert.DoesNotContain(':', Path.GetFileName(path));
        Assert.False(Path.GetFileName(path).StartsWith("CON.", StringComparison.OrdinalIgnoreCase));
    }

    [Fact]
    public void ExistingPhotoIsPreservedAndUnicodeNameSurvives()
    {
        var directory = Path.Combine(Path.GetTempPath(), "meshdrop-path-" + Guid.NewGuid());
        Directory.CreateDirectory(directory);
        try
        {
            var first = Path.Combine(directory, "照片 ✅.jpg");
            File.WriteAllText(first, "original");
            Assert.Equal(Path.Combine(directory, "照片 ✅ (1).jpg"), ReceiveFilePaths.AvailableFile(directory, "照片 ✅.jpg"));
            Assert.Equal("original", File.ReadAllText(first));
        }
        finally { Directory.Delete(directory, true); }
    }
}
