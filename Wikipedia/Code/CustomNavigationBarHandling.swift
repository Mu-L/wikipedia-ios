import Foundation
import SwiftUI
import UIKit
import Combine

enum AdjustingStatus {
    typealias AmountAdjusted = CGFloat
    case complete(CGFloat)
    case adjusting
}

protocol CustomNavigationBarSubviewHeightAdjusting: UIView {
    var order: Int { get }
    var contentHeight: CGFloat { get }
    func updateContentOffset(contentOffset: CGPoint) -> AdjustingStatus
}

class CustomNavigationBarData: ObservableObject {
    @Published var contentOffset: CGPoint = .zero // updated by content views, read by adjusting custom nav bar subviews
    @Published var visibleBarHeight: CGFloat = .zero // not used yet
    @Published var totalBarHeight: CGFloat = .zero //updated at didLayoutSubviews, sum of uncollapsed heights of adjusting custom nav bar subviews
}

private protocol CustomNavigationBarHandling: UIViewController {
    var data: CustomNavigationBarData { get }
    var contentOffsetCancellable: AnyCancellable? { get set }
    var customNavigationBar: CustomNavigationBar { get }
    var customNavigationBarSubviews: [CustomNavigationBarSubviewHeightAdjusting] { get }
}

// Shared Helper Methods

private extension CustomNavigationBarHandling {
    func sharedViewDidLoad() {
        setupCustomNavigationBar()
    }
    
    func sharedViewDidLayoutSubviews() {
        if data.totalBarHeight != customNavigationBar.totalHeight {
            data.totalBarHeight = customNavigationBar.totalHeight
            print("🔵\(data.totalBarHeight)")
        }
        print("customNavigationBar.bounds.height: \(customNavigationBar.bounds.height)")
    }
    
    func setupCustomNavigationBar() {
        
        guard viewIfLoaded != nil else {
            assertionFailure("View not loaded")
            return
        }
        
        navigationController?.isNavigationBarHidden = true

        view.addSubview(customNavigationBar)
        
        NSLayoutConstraint.activate([
            view.safeAreaLayoutGuide.topAnchor.constraint(equalTo: customNavigationBar.topAnchor),
            view.safeAreaLayoutGuide.leadingAnchor.constraint(equalTo: customNavigationBar.leadingAnchor),
            view.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: customNavigationBar.trailingAnchor)
        ])
        
        // Add custom subviews
        customNavigationBar.addCollapsingSubviews(views: customNavigationBarSubviews)
        
        // Initial layout to get data correctly populated initially
        // Without this, data.totalBarHeight doesn't seem to get set properly upon first load.
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        // Setup contentOffset listener, pass it through into custom subviews
        let sortedSubviews = customNavigationBarSubviews.sorted {
            $0.order < $1.order
        }
        
        self.contentOffsetCancellable = data.$contentOffset.sink { newOffset in

            var adjustedDelta: CGFloat = 0
            for subview in sortedSubviews {
                
                let shiftedOffset = CGPoint(x: newOffset.x, y: newOffset.y + adjustedDelta)
                let adjustStatus = subview.updateContentOffset(contentOffset: shiftedOffset)
                
                switch adjustStatus {
                case .complete(let adjustedHeight):
                    adjustedDelta += adjustedHeight
                    continue
                case .adjusting:
                    return
                }
            }
        }
    }
    
    func createCustomNavigationBar() -> CustomNavigationBar {
        let navigationBar = CustomNavigationBar(frame: .zero)
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        return navigationBar
    }
}

// Use for SwiftUI Content (UIHostingControllers)

class CustomNavigationBarHostingController<Content>: UIHostingController<Content>, CustomNavigationBarHandling where Content: View {
    
    var customNavigationBarSubviews: [CustomNavigationBarSubviewHeightAdjusting] {
        fatalError("Must implement in subclass")
    }
    
    var data: CustomNavigationBarData {
        fatalError("Must implement in subclass")
    }
    
    var contentOffsetCancellable: AnyCancellable?
    
    lazy var customNavigationBar: CustomNavigationBar = {
        return createCustomNavigationBar()
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        sharedViewDidLoad()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        sharedViewDidLayoutSubviews()
    }
}

// Use for UIKit Content (UIScrollViews)

class CustomNavigationBarViewController: UIViewController, CustomNavigationBarHandling {
    
    var data = CustomNavigationBarData()
    var contentOffsetCancellable: AnyCancellable?
    
    lazy var customNavigationBar: CustomNavigationBar = {
        return createCustomNavigationBar()
    }()
    
    var customNavigationBarSubviews: [CustomNavigationBarSubviewHeightAdjusting] {
        fatalError("Must implement in subclass")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        sharedViewDidLoad()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        sharedViewDidLayoutSubviews()
    }
}
