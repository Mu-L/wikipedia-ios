import Foundation
import Combine
import WKData

@objc public class WKDeveloperSettingsLocalizedStrings: NSObject {
    let developerSettings: String
    let doNotPostImageRecommendations: String
    let enableAltTextExperiment: String
    let enableAltTextExperimentForEN: String
    let close: String
    
    @objc public init(developerSettings: String, doNotPostImageRecommendations: String, enableAltTextExperiment: String, enableAltTextExperimentForEN: String, close: String) {
        self.developerSettings = developerSettings
        self.doNotPostImageRecommendations = doNotPostImageRecommendations
        self.enableAltTextExperiment = enableAltTextExperiment
        self.enableAltTextExperimentForEN = enableAltTextExperimentForEN
        self.close = close
    }
}

@objc public class WKDeveloperSettingsViewModel: NSObject {
    
    let localizedStrings: WKDeveloperSettingsLocalizedStrings
    let formViewModel: WKFormViewModel
    
    private var subscribers: Set<AnyCancellable> = []
    
    @objc public init(localizedStrings: WKDeveloperSettingsLocalizedStrings) {
        self.localizedStrings = localizedStrings
        let doNotPostImageRecommendationsEditItem = WKFormItemSelectViewModel(title: localizedStrings.doNotPostImageRecommendations, isSelected: WKDeveloperSettingsDataController.shared.doNotPostImageRecommendationsEdit)
        let enableAltTextExperimentItem = WKFormItemSelectViewModel(title: localizedStrings.enableAltTextExperiment, isSelected: WKDeveloperSettingsDataController.shared.enableAltTextExperiment)
        let enableAltTextExperimentItemForENItem = WKFormItemSelectViewModel(title: localizedStrings.enableAltTextExperimentForEN, isSelected: WKDeveloperSettingsDataController.shared.enableAltTextExperimentForEN)

        formViewModel = WKFormViewModel(sections: [WKFormSectionSelectViewModel(items: [doNotPostImageRecommendationsEditItem, enableAltTextExperimentItem, enableAltTextExperimentItemForENItem], selectType: .multi)])

        doNotPostImageRecommendationsEditItem.$isSelected.sink { isSelected in

            WKDeveloperSettingsDataController.shared.doNotPostImageRecommendationsEdit = isSelected

        }.store(in: &subscribers)

        enableAltTextExperimentItem.$isSelected.sink { isSelected in
            WKDeveloperSettingsDataController.shared.enableAltTextExperiment = isSelected
        }.store(in: &subscribers)
        
        enableAltTextExperimentItemForENItem.$isSelected.sink { isSelected in
            WKDeveloperSettingsDataController.shared.enableAltTextExperimentForEN = isSelected
        }.store(in: &subscribers)

    }

}
