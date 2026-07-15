import XCTest
import WMFDataTestSupport
@testable import WMFComponents
@testable import WMFData
@testable import WMFDataMocks

/// Reproduces the onboarding → settings round trip: an article selected on one instance of the
/// interests screen should reappear (selected) when the screen is opened again.
@MainActor
final class WMFInterestsPersistenceRoundTripTests: XCTestCase {

    private let fixture = WMFDataTestFixture()
    private var store: WMFCoreDataStore?
    private let project = WMFProject.wikipedia(WMFLanguage(languageCode: "en", languageVariantCode: nil))

    override func setUp() async throws {
        try await super.setUp()
        await fixture.setUp()
        let store = try await fixture.makeTemporaryCoreDataStore()
        self.store = store
        WMFDataEnvironment.current.coreDataStore = store
        await fixture.resetWMFDataTestState()
    }

    override func tearDown() async throws {
        await fixture.tearDown()
        try await super.tearDown()
    }

    private func waitFor(timeout: TimeInterval = 5, _ condition: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTAssertTrue(condition(), "Condition not met within \(timeout)s")
    }

    func testSelectedArticlePersistsToNewInstance() async throws {
        let store = try XCTUnwrap(store)
        let pageInterest = try WMFPageInterestDataController(coreDataStore: store)
        let home = WMFHomeDataController(userDefaultsStore: WMFMockKeyValueStore())

        // First instance (onboarding): select an article
        let vm1 = WMFHomeFeedInterestsSettingsViewModel(dataController: home, pageInterestDataController: pageInterest, project: project)
        let card = WMFInterestArticleCardViewModel(article: WMFRandomArticle(pageid: 1, title: "Candace_Oviatt", displayTitle: "Candace Oviatt", variantTitles: nil, description: nil, extract: nil, thumbnail: nil), project: project)
        vm1.gridViewModels = [card]
        vm1.toggleArticleSelection(card)
        XCTAssertTrue(card.isSelected)

        // Give the save Task time to persist
        try await waitFor {
            let interests = (try? self.syncFetch(pageInterest)) ?? []
            return !interests.isEmpty
        }

        // Second instance (settings): should load the saved article, selected
        let pageInterest2 = try WMFPageInterestDataController(coreDataStore: store)
        let home2 = WMFHomeDataController(userDefaultsStore: WMFMockKeyValueStore())
        let vm2 = WMFHomeFeedInterestsSettingsViewModel(dataController: home2, pageInterestDataController: pageInterest2, project: project)

        try await waitFor {
            vm2.gridViewModels.contains { $0.isSelected }
        }

        let selected = vm2.gridViewModels.filter { $0.isSelected }
        XCTAssertEqual(selected.count, 1, "Expected the saved article to load as selected")
    }

    /// Mirrors the onboarding launch race: the view model is created without a page interest
    /// controller (Core Data store not ready yet), then resolves it lazily once the store exists.
    func testSelectionPersistsWhenControllerResolvedLazily() async throws {
        let store = try XCTUnwrap(store)
        let home = WMFHomeDataController(userDefaultsStore: WMFMockKeyValueStore())

        // nil controller injected; env store is set, so lazy resolution should succeed on use
        let vm = WMFHomeFeedInterestsSettingsViewModel(dataController: home, pageInterestDataController: nil, project: project)
        let card = WMFInterestArticleCardViewModel(article: WMFRandomArticle(pageid: 2, title: "Marie_Curie", displayTitle: "Marie Curie", variantTitles: nil, description: nil, extract: nil, thumbnail: nil), project: project)
        vm.gridViewModels = [card]
        vm.toggleArticleSelection(card)

        let pageInterest = try WMFPageInterestDataController(coreDataStore: store)
        try await waitFor {
            let interests = (try? self.syncFetch(pageInterest)) ?? []
            return interests.contains { $0.title == "Marie_Curie" }
        }
    }

    private nonisolated func syncFetch(_ controller: WMFPageInterestDataController) throws -> [WMFPageInterest] {
        let semaphore = DispatchSemaphore(value: 0)
        var result: [WMFPageInterest] = []
        let project = WMFProject.wikipedia(WMFLanguage(languageCode: "en", languageVariantCode: nil))
        Task {
            result = (try? await controller.fetchPageInterests(project: project)) ?? []
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }
}
