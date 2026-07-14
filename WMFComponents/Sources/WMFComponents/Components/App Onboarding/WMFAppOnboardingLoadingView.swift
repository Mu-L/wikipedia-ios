import SwiftUI
import Lottie

/// The final onboarding step: a full-screen Lottie animation shown while the chosen feed loads.
/// No toolbar. Completes onboarding once the feed has loaded and the animation has looped at
/// least once (whichever takes longer).
struct WMFAppOnboardingLoadingView: View {

    @ObservedObject var viewModel: WMFAppOnboardingViewModel
    let theme: WMFTheme

    var body: some View {
        VStack(spacing: 24) {
            Text(viewModel.loadingTitle)
                .font(Font(WMFFont.for(.boldTitle1)))
                .foregroundStyle(Color(uiColor: theme.text))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)

            LottieView(animation: .named(viewModel.loadingAnimationName, bundle: .module))
                .looping()
                .frame(width: 200, height: 200)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: theme.paperBackground))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.Onboarding.loadingView)
        .onAppear {
            let loopDuration = LottieAnimation.named(viewModel.loadingAnimationName, bundle: .module)?.duration ?? 2.0
            viewModel.completeAfterLoadingFeed(minimumDisplay: loopDuration)
        }
    }
}
