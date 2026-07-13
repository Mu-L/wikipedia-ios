import UIKit
import WMFNativeLocalizations
import WMFData

@MainActor
public final class WMFAppOnboardingFeedPreferenceViewModel: ObservableObject {

    // MARK: - Strings

    let title = WMFLocalizedString("app-onboarding-feed-preference-title", value: "What would you like to see first?", comment: "Title of the feed preference app onboarding screen, where users choose the content their feed opens on.")
    let communityOptionTitle = WMFLocalizedString("app-onboarding-feed-preference-community-option", value: "Community-related content", comment: "Title of the community content option on the feed preference app onboarding screen.")
    let personalizedOptionTitle = WMFLocalizedString("app-onboarding-feed-preference-personalized-option", value: "Personalized content", comment: "Title of the personalized content option on the feed preference app onboarding screen.")
    let personalizedDisabledExplanation = WMFLocalizedString("app-onboarding-feed-preference-personalized-disabled", value: "You need to add interests to see personalized content suggestions. You can do this in the previous steps or later in Settings.", comment: "Explanation shown on the feed preference app onboarding screen when the personalized content option is unavailable because the user has no interests and no reading history.")
    private let pictureOfTheDayTitle = WMFLocalizedString("app-onboarding-feed-preference-picture-of-the-day", value: "Picture of the day", comment: "Title of the Picture of the Day sample card on the feed preference app onboarding screen.")
    private let inTheNewsTitle = WMFLocalizedString("app-onboarding-feed-preference-in-the-news", value: "In the news", comment: "Title of the In the News sample card on the feed preference app onboarding screen.")

    // MARK: - State

    @Published public private(set) var selection: WMFHomeFeedSeeFirst = .community
    @Published private(set) var communityCards: [WMFAppOnboardingPreviewCardViewModel] = []
    @Published private(set) var personalizedCards: [WMFAppOnboardingPreviewCardViewModel] = []
    @Published private(set) var isPersonalizedAvailable: Bool = true
    @Published private(set) var isLoading: Bool = false

    private let dataController: WMFHomeDataController
    private let project: WMFProject
    private var loadTask: Task<Void, Never>?
    private var hasLoaded = false

    public init(dataController: WMFHomeDataController = WMFHomeDataController.shared, project: WMFProject) {
        self.dataController = dataController
        self.project = project
    }

    // MARK: - Intents

    func select(_ newSelection: WMFHomeFeedSeeFirst) {
        guard newSelection != .personalized || isPersonalizedAvailable else { return }
        selection = newSelection
    }

    /// Skipping onboarding applies the default preference regardless of the current selection.
    public func resetSelectionToDefault() {
        selection = .community
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        isLoading = true
        loadTask = Task { [weak self] in
            guard let self else { return }

            // Day-cached; the previews match what the Home feed will show
            if let community = try? await dataController.fetchCommunity(project: project) {
                self.communityCards = self.buildCommunityCards(from: community)
            }

            // Force fetch: the user just chose interests in the previous step, so any cached
            // For You response predates them. The forced fetch refreshes the shared cache,
            // keeping the Home feed consistent with this preview.
            if let forYou = try? await dataController.fetchForYou(project: project, forceFetch: true) {
                self.personalizedCards = Self.buildPersonalizedCards(from: forYou)
                self.isPersonalizedAvailable = Self.personalizedIsAvailable(for: forYou)
            } else {
                self.personalizedCards = []
                self.isPersonalizedAvailable = !dataController.interestTopics().isEmpty
            }

            if !self.isPersonalizedAvailable && self.selection == .personalized {
                self.selection = .community
            }
            self.isLoading = false
        }
    }

    deinit {
        loadTask?.cancel()
    }

    // MARK: - Card building (internal for unit testing)

    func buildCommunityCards(from response: WMFCommunityResponse) -> [WMFAppOnboardingPreviewCardViewModel] {
        var cards: [WMFAppOnboardingPreviewCardViewModel] = []

        if let featured = response.feedResponse.todaysFeaturedArticle {
            cards.append(WMFAppOnboardingPreviewCardViewModel(
                title: featured.normalizedTitle ?? featured.title ?? "",
                description: featured.description,
                imageURLString: featured.thumbnail?.source,
                topicPill: nil
            ))
        }

        if let pictureOfDay = response.feedResponse.image {
            cards.append(WMFAppOnboardingPreviewCardViewModel(
                title: pictureOfTheDayTitle,
                description: pictureOfDay.description?.text,
                imageURLString: pictureOfDay.thumbnail?.source ?? pictureOfDay.image?.source,
                topicPill: nil
            ))
        }

        if let news = response.feedResponse.news?.first {
            cards.append(WMFAppOnboardingPreviewCardViewModel(
                title: inTheNewsTitle,
                description: news.story.map(Self.strippingHTMLTags),
                imageURLString: news.links?.first?.thumbnail?.source,
                topicPill: nil
            ))
        }

        return cards
    }

    static func buildPersonalizedCards(from response: WMFForYouResponse) -> [WMFAppOnboardingPreviewCardViewModel] {
        var cards: [WMFAppOnboardingPreviewCardViewModel] = []

        // Interests chosen in the previous step: topic interests (with a topic pill) first,
        // then article interests (no topic to show)
        for group in response.interestTopicRandomArticles where cards.count < 3 {
            guard let article = group.articles.first else { continue }
            cards.append(WMFAppOnboardingPreviewCardViewModel(article: article, topicPill: group.topic.displayName))
        }
        for group in response.interestPageRelatedArticles where cards.count < 3 {
            guard let article = group.articles.first ?? Optional(group.pageInterest) else { continue }
            cards.append(WMFAppOnboardingPreviewCardViewModel(article: article, topicPill: nil))
        }

        if cards.isEmpty, let becauseYouRead = response.becauseYouReadArticles {
            cards = becauseYouRead.articles.prefix(3).map {
                WMFAppOnboardingPreviewCardViewModel(article: $0, topicPill: nil)
            }
        }

        return cards
    }

    static func personalizedIsAvailable(for response: WMFForYouResponse) -> Bool {
        let hasInterests = !response.interestTopicRandomArticles.isEmpty || !response.interestPageRelatedArticles.isEmpty
        let hasReadingHistory = response.becauseYouReadArticles != nil || response.continueReadingArticles != nil
        return hasInterests || hasReadingHistory
    }

    static func strippingHTMLTags(_ html: String) -> String {
        return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}

/// A non-interactive sample article card shown on the feed preference onboarding step.
@MainActor
final class WMFAppOnboardingPreviewCardViewModel: ObservableObject, Identifiable {

    let id = UUID()
    let title: String
    let topicPill: String?
    @Published var description: String?
    @Published var uiImage: UIImage?

    private let imageURL: URL?
    private let summaryFetchInfo: (title: String, project: WMFProject)?
    private var loadTask: Task<Void, Never>?

    /// Community cards arrive with all content up front.
    init(title: String, description: String?, imageURLString: String?, topicPill: String?) {
        self.title = title
        self.description = description
        self.imageURL = imageURLString.flatMap { URL(string: $0) }
        self.topicPill = topicPill
        self.summaryFetchInfo = nil
    }

    /// Personalized cards carry only a title and hydrate description/image from the article summary.
    init(article: WMFForYouArticle, topicPill: String?) {
        self.title = article.title.underscoresToSpaces
        self.description = nil
        self.imageURL = nil
        self.topicPill = topicPill
        self.summaryFetchInfo = (article.title, article.project)
    }

    func loadIfNeeded() {
        guard loadTask == nil else { return }
        loadTask = Task { [weak self] in
            guard let self else { return }
            var url = imageURL
            if let info = summaryFetchInfo,
               let summary = try? await WMFArticleSummaryDataController.shared.fetchArticleSummary(project: info.project, title: info.title.spacesToUnderscores) {
                self.description = summary.description
                url = summary.thumbnailURL
            }
            guard let url,
                  let data = try? await WMFImageDataController.shared.fetchImageData(url: url),
                  !Task.isCancelled else { return }
            self.uiImage = UIImage(data: data)
        }
    }

    deinit {
        loadTask?.cancel()
    }
}
