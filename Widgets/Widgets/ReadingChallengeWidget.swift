import WidgetKit
import SwiftUI
import WMF
import WMFComponents
import WMFData
import WMFNativeLocalizations
import WMFTestKitchen

// MARK: - Entry

struct ReadingChallengeEntry: TimelineEntry {
    let date: Date
    let state: ReadingChallengeState
}

// MARK: - Provider

struct ReadingChallengeProvider: TimelineProvider {

    func placeholder(in context: Context) -> ReadingChallengeEntry {
        ReadingChallengeEntry(date: Date(), state: .postChallengeRandomizer)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingChallengeEntry) -> Void) {
        completion(ReadingChallengeEntry(date: Date(), state: .postChallengeRandomizer))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingChallengeEntry>) -> Void) {
        WMFDataEnvironment.current.testKitchenClient = TestKitchenAdapter.shared.client
        Task {
            // Refresh at the next midnight so the display set rotates daily.
            let nextMidnight = Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            )

            let entry = ReadingChallengeEntry(date: Date(), state: .postChallengeRandomizer)
            let timeline = Timeline(entries: [entry], policy: .after(nextMidnight))

            // Flush any stored events before completion — the extension process may be
            // suspended once the completion block returns.
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                EventPlatformClient.shared.flushStoredEvents {
                    continuation.resume()
                }
            }

            completion(timeline)
        }
    }
}

// MARK: - Display Sets

private extension WMFReadingChallengeWidgetViewModel.DisplaySet {

    static func randomIndex(indexKey: WMFUserDefaultsKey, dateKey: WMFUserDefaultsKey, optionsCount: Int) -> Int? {

        guard optionsCount > 0,
              let userDefaults = UserDefaults(suiteName: "group.org.wikimedia.wikipedia") else {
            return nil
        }

        let today = WMFDeveloperSettingsDataController.shared.devReadingChallengeCurrentDate ?? Calendar.current.startOfDay(for: Date())

        if userDefaults.object(forKey: indexKey.rawValue) == nil {
            userDefaults.set(0, forKey: indexKey.rawValue)
            userDefaults.set(today, forKey: dateKey.rawValue)
            return 0
        }

        let index = userDefaults.integer(forKey: indexKey.rawValue)

        let lastDate = userDefaults.object(forKey: dateKey.rawValue) as? Date ?? .distantPast

        guard today > lastDate ||
               WMFDeveloperSettingsDataController.shared.devReadingChallengeState != nil else {
            // On same day, return old index without incrementing.
            // Allow increment on same day if forcing a particular state via dev settings.
            return index
        }

        let nextIndex = (index + 1) % optionsCount
        userDefaults.set(nextIndex, forKey: indexKey.rawValue)
        userDefaults.set(today, forKey: dateKey.rawValue)
        return index
    }

    static func postReadingChallengeRandomizer(family: WidgetFamily) -> WMFReadingChallengeWidgetViewModel.DisplaySet {
        let icon = WMFSFSymbolIcon.for(symbol: .flameFill, font: .boldTitle1)
        let button1Title = family == .systemSmall
            ? CommonStrings.randomButton
            : WMFLocalizedString("reading-challenge-random-article-button", value: "Random article", comment: "Button title on the post-challenge randomizer widget for medium size, linking to a random Wikipedia article.")
        let button1Icon = WMFSFSymbolIcon.for(symbol: .diceFill, font: .semiboldSubheadline)
        let button1URL = URL(string: "wikipedia://random?source=widget_reading_challenge")

        let defaultSet = WMFReadingChallengeWidgetViewModel.DisplaySet(
            color: WMFTheme.ReadingChallengeColorSet.pink.primary,
            color2: WMFTheme.ReadingChallengeColorSet.pink.secondary,
            color3: WMFTheme.ReadingChallengeColorSet.pink.tertiary,
            image: "phoneGlobe",
            title: "",
            subtitle: "",
            button1Title: button1Title,
            button1URL: button1URL,
            button1Icon: button1Icon,
            icon: icon
        )

        let displaySets = [
            defaultSet,
            WMFReadingChallengeWidgetViewModel.DisplaySet(
                color: WMFTheme.ReadingChallengeColorSet.purple.primary,
                color2: WMFTheme.ReadingChallengeColorSet.purple.secondary,
                color3: WMFTheme.ReadingChallengeColorSet.purple.tertiary,
                image: Int.random(in: 1...2) == 1 ? "musicGlobe1" : "musicGlobe2",
                title: "",
                subtitle: "",
                button1Title: button1Title,
                button1URL: button1URL,
                button1Icon: button1Icon,
                icon: icon
            ),
            WMFReadingChallengeWidgetViewModel.DisplaySet(
                color: WMFTheme.ReadingChallengeColorSet.blue.primary,
                color2: WMFTheme.ReadingChallengeColorSet.blue.secondary,
                color3: WMFTheme.ReadingChallengeColorSet.blue.tertiary,
                image: "spaceGlobe",
                title: "",
                subtitle: "",
                button1Title: button1Title,
                button1URL: button1URL,
                button1Icon: button1Icon,
                icon: icon
            )
        ]

        guard let index = randomIndex(
            indexKey: .readingChallengeStreakReadRandomIndex,
            dateKey: .readingChallengeStreakReadRandomIndexDate,
            optionsCount: displaySets.count
        ) else {
            return defaultSet
        }

        return displaySets[index]
    }

    static func make(
        for state: ReadingChallengeState,
        family: WidgetFamily
    ) -> WMFReadingChallengeWidgetViewModel.DisplaySet {
        return postReadingChallengeRandomizer(family: family)
    }
}

// MARK: - Entry View

struct ReadingChallengeEntryView: View {
    let entry: ReadingChallengeEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        let displaySet = WMFReadingChallengeWidgetViewModel.DisplaySet.make(
            for: entry.state,
            family: family
        )
        return WMFReadingChallengeWidgetView(
            viewModel: WMFReadingChallengeWidgetViewModel(
                localizedStrings: WMFReadingChallengeWidgetViewModel.LocalizedStrings(
                    title: displaySet.title
                ),
                displaySet: displaySet,
                state: entry.state
            )
        )
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetURL(URL(string: "wikipedia://random?source=widget_reading_challenge"))
    }
}

// MARK: - Widget

struct ReadingChallengeWidget: Widget {
    private let kind: String = WidgetController.SupportedWidget.readingChallenge.identifier

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadingChallengeProvider()) { entry in
            ReadingChallengeEntryView(entry: entry)
        }
        .configurationDisplayName(WMFLocalizedString("reading-challenge-widget-display-name", value: "Random article", comment: "Display name for the random article widget shown in the widget picker."))
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(false)
    }
}
