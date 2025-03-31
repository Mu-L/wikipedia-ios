import Foundation

@objc public class WMFTempAccountDataController: NSObject {
    @objc public static let shared = WMFTempAccountDataController()
    
    private var mediaWikiService = WMFDataEnvironment.current.mediaWikiService

    private let userDefaultsStore = WMFDataEnvironment.current.userDefaultsStore

    private var _primaryWikiHasTempAccountsEnabled: Bool?
    @objc public var primaryWikiHasTempAccountsEnabled: Bool {
        return _primaryWikiHasTempAccountsEnabled ?? false
    }

    private var sharedCacheStore: WMFKeyValueStore? = WMFDataEnvironment.current.sharedCacheStore
    private let cacheDirectoryName = WMFSharedCacheDirectoryNames.tempAccountsWikis.rawValue
    private let cacheLocalTempAccountsFileName = "AppTempAccountsWikiList"

    public func wikisWithTempAccountsEnabled() -> [String] {
        guard let cachedWikis: [String] = try? sharedCacheStore?.load(key: cacheDirectoryName, cacheLocalTempAccountsFileName) else {
            return []
        }
        return cachedWikis
    }

    @objc public func checkWikiTempAccountAvailability(language: String, isCheckingPrimaryWiki: Bool) {

        var wikis = wikisWithTempAccountsEnabled()

        Task {
            do {
                let hasTempStatus = try await getTempAccountStatusForWiki(language: language)
                if !wikis.contains(language) && hasTempStatus {
                    wikis.append(language)
                    try? self.sharedCacheStore?.save(key: self.cacheDirectoryName, self.cacheLocalTempAccountsFileName, value: wikis)
                }

                if isCheckingPrimaryWiki {
                    _primaryWikiHasTempAccountsEnabled = hasTempStatus
                }

            } catch {
                print("Error fetching temporary account status: \(error)")
            }
        }
    }

    private func getTempAccountStatusForWiki(language: String) async throws -> Bool {
        let wmfLanguage = WMFLanguage(languageCode: language, languageVariantCode: nil)
        let project = WMFProject.wikipedia(wmfLanguage)

        return try await withCheckedThrowingContinuation { continuation in
            fetchWikiTempStatus(project: project) { status in
                switch status {
                case .success(let isTemporary):
                    continuation.resume(returning: isTemporary)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func fetchWikiTempStatus(project: WMFProject, completion: ((Result<Bool, Error>) -> Void)? = nil) {
        guard let mediaWikiService else {
            completion?(.failure(WMFDataControllerError.mediaWikiServiceUnavailable))
            return
        }

        guard let url = URL.mediaWikiAPIURL(project: project) else {
            completion?(.failure(WMFDataControllerError.failureCreatingRequestURL))
            return
        }

        let parameters: [String: Any] = [
            "action": "query",
            "format": "json",
            "meta": "siteinfo",
            "formatversion": "2",
            "siprop": "autocreatetempuser"
        ]

        let request = WMFMediaWikiServiceRequest(url:url, method: .GET, backend: .mediaWiki, parameters: parameters)

        mediaWikiService.performDecodableGET(request: request) { (result: Result<TempStatusResponse, Error>) in
            switch result {
            case .success(let response):
                completion?(.success(response.query.autocreatetempuser.enabled))
            case .failure(let error):
                completion?(.failure(error))

            }
        }
    }
}

private struct TempStatusResponse: Codable {
    let batchcomplete: Bool
    let query: TempStatusQuery
}

private struct TempStatusQuery: Codable {
    let autocreatetempuser: AutoCreateTempUser
}

private struct AutoCreateTempUser: Codable {
    let enabled: Bool
}
