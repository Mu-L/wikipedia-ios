import UIKit
import WMF
import WMFComponents
import WMFData
import WMFNativeLocalizations

/// Presents the app-launch onboarding flow and handles its app-side navigation
/// (web views, the preferred languages editor) and completion.
@MainActor
final class AppOnboardingCoordinator: NSObject {

    private weak var presentingViewController: UIViewController?
    private let dataStore: MWKDataStore
    private let theme: Theme
    private let completion: () -> Void

    private var viewModel: WMFAppOnboardingViewModel?
    private(set) var hostingController: WMFAppOnboardingHostingController?

    init(presentingViewController: UIViewController, dataStore: MWKDataStore, theme: Theme, completion: @escaping () -> Void) {
        self.presentingViewController = presentingViewController
        self.dataStore = dataStore
        self.theme = theme
        self.completion = completion
    }

    func start() {
        let language = WMFHomeDataController.shared.selectedLanguage() ?? WMFDataEnvironment.current.primaryAppLanguage ?? WMFLanguage(languageCode: "en", languageVariantCode: nil)
        let project = WMFProject.wikipedia(language)
        let interestsViewModel = WMFHomeFeedInterestsSettingsViewModel(project: project, searchLanguages: preferredWMFLanguages())

        let viewModel = WMFAppOnboardingViewModel(
            languages: preferredLanguageItems(),
            interestsViewModel: interestsViewModel,
            didTapLearnMoreAboutWikipedia: { [weak self] in
                self?.presentWebView(urlString: CommonStrings.aboutWikipediaURLString)
            },
            didTapPrivacyPolicy: { [weak self] in
                self?.presentWebView(urlString: CommonStrings.privacyPolicyURLString)
            },
            didTapTermsOfUse: { [weak self] in
                self?.presentWebView(urlString: CommonStrings.termsOfUseURLString)
            },
            didTapAddLanguages: { [weak self] in
                self?.presentPreferredLanguages()
            },
            onCompletion: { [weak self] in
                self?.finish()
            }
        )
        self.viewModel = viewModel

        let hostingController = WMFAppOnboardingHostingController(viewModel: viewModel)
        hostingController.modalPresentationStyle = .overFullScreen
        hostingController.modalPresentationCapturesStatusBarAppearance = true
        self.hostingController = hostingController
        presentingViewController?.present(hostingController, animated: false)
    }

    // MARK: - Languages

    private func preferredLanguageItems() -> [WMFAppOnboardingViewModel.LanguageItem] {
        return dataStore.languageLinkController.preferredLanguages.enumerated().map { index, language in
            WMFAppOnboardingViewModel.LanguageItem(id: language.contentLanguageCode, displayName: language.name, isPrimary: index == 0)
        }
    }

    private func preferredWMFLanguages() -> [WMFLanguage] {
        return dataStore.languageLinkController.preferredLanguages.map {
            WMFLanguage(languageCode: $0.languageCode, languageVariantCode: $0.languageVariantCode)
        }
    }

    private func presentPreferredLanguages() {
        guard let hostingController else { return }
        let languagesVC = WMFPreferredLanguagesViewController.preferredLanguagesViewController()
        languagesVC.showExploreFeedCustomizationSettings = false
        languagesVC.delegate = self
        languagesVC.apply(theme)
        let navVC = WMFComponentNavigationController(rootViewController: languagesVC, modalPresentationStyle: .overFullScreen)
        hostingController.present(navVC, animated: true)
    }

    // MARK: - Web views

    private func presentWebView(urlString: String) {
        guard let hostingController, let url = URL(string: urlString) else { return }
        let config = SinglePageWebViewController.StandardConfig(url: url, useSimpleNavigationBar: true)
        let webVC = SinglePageWebViewController(configType: .standard(config), theme: theme)
        let navVC = WMFComponentNavigationController(rootViewController: webVC, modalPresentationStyle: .fullScreen)
        hostingController.present(navVC, animated: true)
    }

    // MARK: - Completion

    private func finish() {
        if viewModel?.interestsViewModel.hasChanges == true {
            NotificationCenter.default.post(name: WMFNSNotification.forYouInterestsDidChange, object: nil)
        }
        hostingController?.dismiss(animated: true) { [weak self] in
            self?.completion()
        }
    }
}

extension AppOnboardingCoordinator: WMFPreferredLanguagesViewControllerDelegate {
    nonisolated func languagesController(_ controller: WMFPreferredLanguagesViewController, didUpdatePreferredLanguages languages: [MWKLanguageLink]) {
        // UIKit invokes this delegate on the main thread
        MainActor.assumeIsolated {
            viewModel?.updateLanguages(preferredLanguageItems())
            viewModel?.interestsViewModel.updateSearchLanguages(preferredWMFLanguages())
        }
    }
}
