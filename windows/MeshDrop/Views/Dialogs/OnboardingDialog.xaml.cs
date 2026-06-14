using Microsoft.UI.Xaml.Controls;

namespace MeshDrop.Views.Dialogs;

public sealed partial class OnboardingDialog : ContentDialog
{
    public OnboardingDialog()
    {
        InitializeComponent();
        // ContentDialog 按钮文案在此本地化（x:Uid 对 ContentDialog 按钮属性支持不稳，统一走代码）。
        CloseButtonText = I18n.T("onboarding.skip");
        PrimaryButtonText = I18n.T("onboarding.start");
    }
}
