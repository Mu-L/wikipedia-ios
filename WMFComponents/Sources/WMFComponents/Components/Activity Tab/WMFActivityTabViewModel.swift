import Foundation
import SwiftUI
import WMFData

struct ArticlesReadViewModel {
    var username: String
    var hoursRead: Int
    var minutesRead: Int
    var totalArticlesRead: Int
    var dateTimeLastRead: String
	var weeklyReads: [Int]
	var topCategories: [String]
    var articlesSavedAmount: Int
    var dateTimeLastSaved: String
    var articlesSavedImages: [URL]
}

@MainActor
public class WMFActivityTabViewModel: ObservableObject {
    let localizedStrings: LocalizedStrings
    private let dataController: WMFActivityTabDataController
    @Published var articlesReadViewModel: ArticlesReadViewModel?
    var hasSeenActivityTab: () -> Void
    public var navigateToSaved: (() -> Void)?
    
    public init(localizedStrings: LocalizedStrings,
                dataController: WMFActivityTabDataController,
                hasSeenActivityTab: @escaping () -> Void) {
        self.localizedStrings = localizedStrings
        self.dataController = dataController
        self.hasSeenActivityTab = hasSeenActivityTab
    }
    
    func fetchData() {
        Task {
            async let timeResult = dataController.getTimeReadPast7Days()
            async let articlesResult = dataController.getArticlesRead()
            async let dateResult = dataController.getMostRecentReadDateTime()
            async let weeklyResults = dataController.getWeeklyReadsThisMonth()
            async let categoriesResult = dataController.getTopCategories()
            
            let (hours, minutes) = (try? await timeResult) ?? (0, 0)
            let totalArticlesRead = (try? await articlesResult) ?? 0
            let dateTime = (try? await dateResult) ?? Date()
			let weeklyReads = (try? await weeklyResults) ?? []
			let categories = (try? await categoriesResult) ?? []
            
            let formattedDate = self.formatDateTime(dateTime)
            
            await MainActor.run {
                self.articlesReadViewModel = ArticlesReadViewModel(
                    username: "",
                    hoursRead: hours,
                    minutesRead: minutes,
                    totalArticlesRead: totalArticlesRead,
                    dateTimeLastRead: formattedDate,
					weeklyReads: weeklyReads,
					topCategories: categories,
                    articlesSavedAmount: 27,
                    dateTimeLastSaved: "November 82",
                    articlesSavedImages: images
                )
            }
        }
    }
    
    let images: [URL] = [
        URL(string: "https://upload.wikimedia.org/wikipedia/commons/4/47/PNG_transparency_demonstration_1.png")!,
        URL(string: "https://upload.wikimedia.org/wikipedia/commons/0/0b/Baker_Harcourt_1940_2.jpg")!,
        URL(string: "https://upload.wikimedia.org/wikipedia/commons/1/10/Arch_of_SeptimiusSeverus.jpg")!,
        URL(string: "https://upload.wikimedia.org/wikipedia/commons/8/81/Ivan_Akimov_Saturn_.jpg")!,
        URL(string: "https://upload.wikimedia.org/wikipedia/commons/6/6a/She-wolf_suckles_Romulus_and_Remus.jpg")!
    ]

    
    // MARK: - View Strings
    
    public var usernamesReading: String {
        guard let model = articlesReadViewModel else { return "" }
        if model.username.isEmpty {
            return localizedStrings.noUsernameReading
        }
        return localizedStrings.userNamesReading(model.username)
    }
    
    public var hoursMinutesRead: String {
        guard let model = articlesReadViewModel else { return "" }
        return localizedStrings.totalHoursMinutesRead(model.hoursRead, model.minutesRead)
    }
    
    // MARK: - Update
    
    public func updateUsername(username: String) {
        guard var model = articlesReadViewModel else { return }
        model.username = username
        articlesReadViewModel = model
    }
    
    private func updateHoursMinutesRead(hours: Int, minutes: Int) {
        guard var model = articlesReadViewModel else { return }
        model.hoursRead = hours
        model.minutesRead = minutes
        articlesReadViewModel = model
    }
    
    private func updateTotalArticlesRead(totalArticlesRead: Int) {
        guard var model = articlesReadViewModel else { return }
        model.totalArticlesRead = totalArticlesRead
        articlesReadViewModel = model
    }
    
    private func updateDateTimeRead(dateTime: Date) {
        guard var model = articlesReadViewModel else { return }
        model.dateTimeLastRead = formatDateTime(dateTime)
        articlesReadViewModel = model
    }

 	private func updateWeeklyReads(weeklyReads: [Int]) {
        guard var model = articlesReadViewModel else { return }
        model.weeklyReads = weeklyReads
        articlesReadViewModel = model
    }
    
    private func updateTopCategories(topCategories: [String]) {
        guard var model = articlesReadViewModel else { return }
        model.topCategories = topCategories
        articlesReadViewModel = model
    }
    
    // MARK: - Helpers
    
    private func formatDateTime(_ dateTime: Date) -> String {
        DateFormatter.wmfLastReadFormatter(for: dateTime)
    }
    
    // MARK: - Localized Strings
    
    public struct LocalizedStrings {
        let userNamesReading: (String) -> String
        let noUsernameReading: String
        let totalHoursMinutesRead: (Int, Int) -> String
        let onWikipediaiOS: String
        let timeSpentReading: String
        let totalArticlesRead: String
        let week: String
        let articlesRead: String
        let topCategories: String
        let articlesSavedTitle: String
        let remaining: (Int) -> String
        
        public init(userNamesReading: @escaping (String) -> String, noUsernameReading: String, totalHoursMinutesRead: @escaping (Int, Int) -> String, onWikipediaiOS: String, timeSpentReading: String, totalArticlesRead: String, week: String, articlesRead: String, topCategories: String, articlesSavedTitle: String, remaining: @escaping (Int) -> String) {
            self.userNamesReading = userNamesReading
            self.noUsernameReading = noUsernameReading
            self.totalHoursMinutesRead = totalHoursMinutesRead
            self.onWikipediaiOS = onWikipediaiOS
            self.timeSpentReading = timeSpentReading
            self.totalArticlesRead = totalArticlesRead
            self.week = week
            self.articlesRead = articlesRead
            self.topCategories = topCategories
            self.articlesSavedTitle = articlesSavedTitle
            self.remaining = remaining
        }
    }
}
