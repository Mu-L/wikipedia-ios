import SwiftUI

public struct WMFAppOnboardingView: View {

    @ObservedObject var viewModel: WMFAppOnboardingViewModel
    @ObservedObject var appEnvironment = WMFAppEnvironment.current

    public init(viewModel: WMFAppOnboardingViewModel) {
        self.viewModel = viewModel
    }

    /// The intro step is always dark, regardless of the app theme.
    private var theme: WMFTheme {
        return viewModel.currentStep == .intro ? .dark : appEnvironment.theme
    }

    private var colorScheme: ColorScheme {
        return viewModel.currentStep == .intro ? .dark : appEnvironment.theme.preferredColorScheme
    }

    /// Bottom inset so scrollable step content isn't covered by the floating toolbar.
    static let toolbarContentInset: CGFloat = 96

    public var body: some View {
        ZStack(alignment: .bottom) {
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)

            WMFAppOnboardingToolbar(viewModel: viewModel, theme: theme)
        }
        .background(Color(uiColor: theme.paperBackground).ignoresSafeArea())
        .environment(\.colorScheme, colorScheme)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.currentStep {
        case .intro:
            WMFAppOnboardingIntroView(viewModel: viewModel)
        case .dataPrivacy:
            WMFAppOnboardingDataPrivacyView(viewModel: viewModel, theme: theme)
        case .languages:
            WMFAppOnboardingLanguagesView(viewModel: viewModel, theme: theme)
        case .personalizationIntro:
            WMFAppOnboardingPersonalizationIntroView(viewModel: viewModel, theme: theme)
        case .interests:
            VStack(spacing: 0) {
                WMFHomeFeedInterestsSettingsView(viewModel: viewModel.interestsViewModel, bottomContentInset: Self.toolbarContentInset)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityIdentifiers.Interests.view)
        }
    }
}

struct WMFAppOnboardingToolbar: View {

    @ObservedObject var viewModel: WMFAppOnboardingViewModel
    let theme: WMFTheme

    private static let controlHeight: CGFloat = 44

    var body: some View {
        ZStack {
            if viewModel.showsSkipAndDots {
                HStack {
                    Button(viewModel.skipTitle) {
                        viewModel.skip()
                    }
                    .font(Font(WMFFont.for(.body)))
                    .foregroundStyle(Color(uiColor: theme.text))
                    .padding(.horizontal, 20)
                    .frame(height: Self.controlHeight)
                    .modifier(WMFAppOnboardingPillBackground(theme: theme, isInteractive: true))
                    .accessibilityIdentifier(AccessibilityIdentifiers.Onboarding.skipButton)

                    Spacer()
                }

                dots
            }

            HStack {
                Spacer()
                nextButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(0..<viewModel.personalizationSteps.count, id: \.self) { index in
                Circle()
                    .fill(index == viewModel.currentDotIndex ? Color(uiColor: theme.text) : Color(uiColor: theme.secondaryText).opacity(0.4))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: Self.controlHeight)
        .modifier(WMFAppOnboardingPillBackground(theme: theme, isInteractive: false))
    }

    private var nextButton: some View {
        Button {
            withAnimation {
                viewModel.advance()
            }
        } label: {
            Group {
                if let chevron = WMFSFSymbolIcon.for(symbol: .chevronForward, font: .boldHeadline) {
                    Image(uiImage: chevron)
                        .foregroundStyle(Color(uiColor: theme.text))
                }
            }
            .frame(width: Self.controlHeight, height: Self.controlHeight)
        }
        .modifier(WMFAppOnboardingPillBackground(theme: theme, isInteractive: true))
        .accessibilityLabel(viewModel.nextAccessibilityLabel)
        .accessibilityIdentifier(AccessibilityIdentifiers.Onboarding.nextButton)
    }
}

/// Shared background for the onboarding toolbar controls: liquid glass on iOS 26+,
/// a translucent capsule on earlier versions.
private struct WMFAppOnboardingPillBackground: ViewModifier {
    let theme: WMFTheme
    let isInteractive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(isInteractive ? .regular.interactive() : .regular, in: Capsule())
        } else {
            content
                .background(
                    Capsule()
                        .fill(Color(uiColor: theme.midBackground).opacity(0.9))
                )
        }
    }
}
