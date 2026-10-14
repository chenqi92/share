using MeshDrop.Models;
using Xunit;

namespace MeshDrop.Transport.Tests;

public sealed class ReceivePolicyTests
{
    [Theory]
    [InlineData(true, true, true)]
    [InlineData(false, true, false)]
    [InlineData(true, false, false)]
    [InlineData(false, false, false)]
    public void OnlyTrustedPeersSkipConfirmation(bool trusted, bool enabled, bool expected)
    {
        var settings = new AppSettings { AutoAcceptTrusted = enabled };
        Assert.Equal(expected, settings.ShouldAutoAccept(trusted));
    }

    [Fact]
    public void ConflictingLegacyDefaultsMigrateToAutomaticTrustedReceive()
    {
        var settings = AppSettings.FromJson("""
            {"verify_before_receive":true,"auto_accept_trusted":false}
            """);
        Assert.True(settings.ShouldAutoAccept(true));
        Assert.False(settings.ShouldAutoAccept(false));
    }

    [Fact]
    public void ExplicitLegacyManualChoiceIsPreserved()
    {
        var settings = AppSettings.FromJson("""
            {"verify_before_receive":false,"auto_accept_trusted":false}
            """);
        Assert.False(settings.ShouldAutoAccept(true));
    }

    [Fact]
    public void NewManualChoiceSurvivesSerialization()
    {
        var original = new AppSettings { AutoAcceptTrusted = false };
        var settings = AppSettings.FromJson(System.Text.Json.JsonSerializer.Serialize(original));
        Assert.False(settings.ShouldAutoAccept(true));
    }

    [Fact]
    public void OldStrangerPreferenceCannotBypassTrust()
    {
        var settings = AppSettings.FromJson("""
            {"verify_before_receive":false,"auto_accept_trusted":true,"auto_accept_stranger":true}
            """);
        Assert.False(settings.ShouldAutoAccept(false));
    }
}
