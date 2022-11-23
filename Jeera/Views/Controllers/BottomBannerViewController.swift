//
//  BottomBannerViewController.swift
//  Jeera
//
//  Created by Wildan Budi on 23/10/22.
//

import UIKit
import MapboxNavigation
import CoreLocation
import MapboxDirections
import MapboxCoreNavigation

class BottomBannerViewController: ContainerViewController, BottomBarViewDelegate {
    
    var animalName: String?
    weak var animalDetailViewController: AnimalDetailViewController?
    weak var mainViewController: MainViewController?
    weak var routePlanViewController: RoutePlanViewController?
    weak var navigationViewController: NavigationViewController?
    
    // Or you can implement your own UI elements
    lazy var bannerView: BottomBarView = {
        let banner = BottomBarView()
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.layer.cornerRadius = 20
        banner.delegate = self
        return banner
    }()
    
    override func loadView() {
        super.loadView()
        
        view.addSubview(bannerView)
        
        let safeArea = view.layoutMarginsGuide
        NSLayoutConstraint.activate([
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerView.heightAnchor.constraint(equalTo: view.heightAnchor),
        ])
//        self.modalPresentationStyle = .popover
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupConstraints()
    }
    
    private func setupConstraints() {
        //    if let superview = view.superview?.superview {
        //    view.bottomAnchor.constraint(equalTo: superview.safeAreaLayoutGuide.bottomAnchor).isActive = true
        //    }
    }
    
    // MARK: - NavigationServiceDelegate implementation
    
    func navigationService(_ service: NavigationService, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation) {
        // pass updated data to sub-views which also implement `NavigationServiceDelegate`
        bannerView.eta = "\(Int(round(progress.durationRemaining / 60))) menit"
        bannerView.animalName = progress.routeOptions.waypoints[1].name
        animalName = bannerView.animalName
    }
    
    func navigationService(_ service: NavigationService, didArriveAt waypoint: Waypoint) -> Bool {
        let endRouteVC = EndOfRouteViewController()
        endRouteVC.animalName = animalName!
        endRouteVC.modalPresentationStyle = .popover
        present(endRouteVC, animated: true)
        
        return false
    }
    
    // MARK: - CustomBottomBannerViewDelegate implementation
    
    func customBottomBannerDidCancel(_ banner: BottomBarView) {
        self.view.window!.rootViewController?.dismiss(animated: true, completion: nil)
    }
}

#if DEBUG
import SwiftUI

@available(iOS 13, *)
struct BottomBannerViewController_Preview: PreviewProvider {
    static var previews: some View {
        // view controller using programmatic UI
        Group {
            BottomBannerViewController().showPreview().previewInterfaceOrientation(.portrait)
        }
    }
}
#endif
