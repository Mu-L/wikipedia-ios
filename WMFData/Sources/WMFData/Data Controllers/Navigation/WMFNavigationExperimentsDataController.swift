import Foundation

public final class WMFNavigationExperimentsDataController {
    
    public enum CustomError: Error {
        case invalidProject
        case invalidDate
        case alreadyAssignedBucket
        case missingAssignment
        case unexpectedAssignment
    }
    
    public enum ArticleSearchBarExperimentAssignment {
        case control
        case test
    }
    
    public static let shared = WMFNavigationExperimentsDataController()
    private let experimentsDataController: WMFExperimentsDataController
    private let articleSearchBarExperimentPercentage: Int = 50
    
    private var assignmentCache: ArticleSearchBarExperimentAssignment?
    
    private init?(experimentStore: WMFKeyValueStore? = WMFDataEnvironment.current.sharedCacheStore) {
        guard let experimentStore else {
            return nil
        }
        self.experimentsDataController = WMFExperimentsDataController(store: experimentStore)
    }
    
    public func assignArticleSearchBarExperiment(project: WMFProject) throws -> ArticleSearchBarExperimentAssignment {
        
        guard project.qualifiesForNavigationV2Experiment() else {
            throw CustomError.invalidProject
        }
        
        guard isBeforeEndDate else {
            throw CustomError.invalidDate
        }
        
        if let assignmentCache {
            throw CustomError.alreadyAssignedBucket
        }
        
        if experimentsDataController.bucketForExperiment(.articleSearchBar) != nil {
            throw CustomError.alreadyAssignedBucket
        }
        
        let bucketValue = try experimentsDataController.determineBucketForExperiment(.articleSearchBar, withPercentage: articleSearchBarExperimentPercentage)
        
        let assignment: ArticleSearchBarExperimentAssignment
        switch bucketValue {
        case .articleSearchBarTest:
            assignment = ArticleSearchBarExperimentAssignment.test
        case .articleSearchBarControl:
            assignment = ArticleSearchBarExperimentAssignment.control
        default:
            throw CustomError.unexpectedAssignment
        }
        
        self.assignmentCache = assignment
        return assignment
    }
    
    public func articleSearchBarExperimentAssignment() throws -> ArticleSearchBarExperimentAssignment {
        
        // Check cache first
        if let assignmentCache {
            return assignmentCache
        }
        
        guard let bucketValue = experimentsDataController.bucketForExperiment(.articleSearchBar) else {
            throw CustomError.missingAssignment
        }
        
        let assignment: ArticleSearchBarExperimentAssignment
        switch bucketValue {
        case .articleSearchBarTest:
            assignment = ArticleSearchBarExperimentAssignment.test
        case .articleSearchBarControl:
            assignment = ArticleSearchBarExperimentAssignment.control
        default:
            throw CustomError.unexpectedAssignment
        }
        
        self.assignmentCache = assignment
        return assignment
    }
    
    private var experimentStopDate: Date? {
        var dateComponents = DateComponents()
        dateComponents.year = 2025
        dateComponents.month = 31
        dateComponents.day = 5
        return Calendar.current.date(from: dateComponents)
    }
    
    private var isBeforeEndDate: Bool {
        
        guard let experimentStopDate else {
            return false
        }
        
        return experimentStopDate >= Date()
    }
}

private extension WMFProject {
    func qualifiesForNavigationV2Experiment() -> Bool {
        switch self {
        case .wikipedia(let language):
            switch language.languageCode {
            case "fr", "ar", "de", "ja":
                return true
            default:
                return false
            }
        default:
            return false
        }
    }
}
