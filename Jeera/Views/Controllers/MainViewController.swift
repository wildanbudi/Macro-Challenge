//
//  MainViewController.swift
//  Jeera
//
//  Created by Anggi Dastariana on 24/10/22.
//
import UIKit
import MapboxMaps
import MapboxDirections

class MainViewController: UIViewController {
    internal var mapView: MapView!
    internal var mapViewRetrieveData: MapView!
    internal var cameraLocationConsumer: CameraLocationConsumer!
    internal var pointAnnotationManager: PointAnnotationManager!
    internal var targetCoordinate: CLLocationCoordinate2D!
    internal var annotationData: Dictionary<String, JSONValue>!
    internal var userLocation: CLLocationCoordinate2D? = centerCoordinate
    internal var animalsData: [AllData] = []
    internal var facilitiesData: [AllData] = []
    internal var cagesData: [AllData] = []
    
    lazy var whiteBackground = UIView()
    lazy var segmentedBase = UIView()
    lazy var segmentedButtons = [UIButton]()
    lazy var segmentedSelector = UIView()
    lazy var selectedSegmentIndex = 0
    lazy var buttonLocationOFF = UIButton(type: .custom)
    lazy var searchButton = SearchButton()
    
    var timer = Timer()
    
    // Initiate The Core Location Manager
    let locationManager = CLLocationManager()
    
    // Set the iPhone Status Bar to Dark
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .darkContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMapView()
        segmentedBackground()
        locationOffButton()
        customSegmentedControl()
        setupSearchBtn()
        setupConstraint()
        
        // Check the User's Core Location Status Through the CLLocationDelegate Function
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.startUpdatingLocation()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.animalsData.count == 0 {
            timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(retrieveAnnotationData), userInfo: nil, repeats: true)
        }
    }
    
    func setupMapView() {
        let mapRetrieveInstance = Map()
        mapRetrieveInstance.zoomLevel = 10
        mapViewRetrieveData = mapRetrieveInstance.getMapView()
        view.addSubview(mapViewRetrieveData)
        
        let mapInstance = Map()
        mapInstance.zoomLevel = 16
        mapView = mapInstance.getMapView()
        mapView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(onMapClick)))
        view.addSubview(mapView)
    }
    
    @objc func retrieveAnnotationData() {
        timer.invalidate()
        let queryOptions = RenderedQueryOptions(layerIds: layerStyleOverlapIds, filter: nil)
        mapViewRetrieveData.mapboxMap.queryRenderedFeatures(with: mapView.safeAreaLayoutGuide.layoutFrame, options: queryOptions, completion: { [weak self] result in
            switch result {
            case .success(let queriedFeatures):
//                print(queriedFeatures.count)
                if queriedFeatures.count > 0 {
                    self!.animalsData.removeAll()
                    self!.cagesData.removeAll()
                    self!.facilitiesData.removeAll()
                    for data in queriedFeatures {
                        let parsedFeature = data.feature.properties!.reduce(into: [:]) { $0[$1.0] = $1.1 }
                        let typeFeature = parsedFeature["type"]!.rawValue as! String
                        if let geometry = data.feature.geometry, case let Geometry.point(point) = geometry {
                            let coordinate = point.coordinates
                            self!.mappingAnnotationData(locationCoordinate: coordinate, parsedFeature: parsedFeature, typeFeature: typeFeature)
                        }
                    }
                }
            case .failure(let error):
                print(error.localizedDescription)
            }
        })
    }
    
    func setupUserLocation() {
        cameraLocationConsumer = CameraLocationConsumer(mapView: mapView)
        let configuration = Puck2DConfiguration(topImage: UIImage(named: "Current Location"))
        mapView.location.options.puckType = .puck2D(configuration)
        
        mapView.mapboxMap.onNext(event: .mapLoaded) { _ in
            // Register the location consumer with the map
            // Note that the location manager holds weak references to consumers, which should be retained
            self.mapView.location.addLocationConsumer(newConsumer: self.cameraLocationConsumer)
            
            //            self.finish() // Needed for internal testing purposes.
        }
    }
    
    func setupSearchBtn() {
        searchButton.addTarget(self, action: #selector(searchButtonClick(_:)), for: .touchUpInside)
        view.addSubview(searchButton)
    }
    
    @objc private func searchButtonClick(_ sender: UIButton) {
        let searchViewController = SearchViewController()
        searchViewController.modalPresentationStyle = .formSheet
        searchViewController.animalsData = self.animalsData
        searchViewController.facilitiesData = self.facilitiesData
        searchViewController.userLocation = self.userLocation
        self.present(searchViewController, animated: true, completion: nil)
        
    }
    
    func mappingAnnotationData(locationCoordinate: CLLocationCoordinate2D, parsedFeature: Dictionary<String, JSONValue>, typeFeature: String) {
        if userLocation != nil {
            let directions = Directions.shared
            let waypoints = [
                Waypoint(coordinate: userLocation!, name: "origin"),
                Waypoint(coordinate: locationCoordinate, name: "destination"),
            ]
            let options = RouteOptions(waypoints: waypoints, profileIdentifier: .walking)
            let _ = directions.calculate(options) { (session, result) in
                switch result {
                case .failure(let error):
                    print("Error calculating directions: \(error)")
                    return
                case .success(let response):
                    guard let route = response.routes?.first, let _ = route.legs.first else {
                        return
                    }
                    self.appendAnnotationData(typeFeature: typeFeature, parsedFeature: parsedFeature, locationCoordinate: locationCoordinate, distance: route.distance, travelTime: (route.expectedTravelTime/60) + 1)
                }
            }
        } else {
            appendAnnotationData(typeFeature: typeFeature, parsedFeature: parsedFeature, locationCoordinate: locationCoordinate)
        }
    }
    
    func appendAnnotationData(typeFeature: String, parsedFeature: Dictionary<String, JSONValue>, locationCoordinate: CLLocationCoordinate2D, distance: Double = 0.0, travelTime: Double = 0.0) {
        if typeFeature == "Hewan" {
            var dict = parsedFeature
            let clusterName = getClusterName(idName: parsedFeature["cage"]!.rawValue as! String)
            dict["clusterName"] = JSONValue(clusterName)
            self.animalsData.append(
                AllData(
                    cage: parsedFeature["cage"]!.rawValue as! String,
                    idName: parsedFeature["idName"]!.rawValue as! String,
                    enName: parsedFeature["enName"]!.rawValue as! String,
                    latinName: parsedFeature["latinName"]!.rawValue as! String,
                    type: parsedFeature["type"]!.rawValue as! String,
                    clusterName: clusterName,
                    lat: locationCoordinate.latitude,
                    long: locationCoordinate.longitude,
                    distance: Int(distance),
                    travelTime: Int(travelTime),
                    dict: dict
                )
            )
        } else if typeFeature != "Kandang" && typeFeature != "Hewan" {
            self.facilitiesData.append(
                AllData(
                    cage: "",
                    idName: parsedFeature["idName"]!.rawValue as! String,
                    enName: parsedFeature["enName"]!.rawValue as! String,
                    latinName: "",
                    type: parsedFeature["type"]!.rawValue as! String,
                    clusterName: parsedFeature["clusterName"]!.rawValue as! String,
                    lat: locationCoordinate.latitude,
                    long: locationCoordinate.longitude,
                    distance: Int(distance),
                    travelTime: Int(travelTime),
                    dict: parsedFeature
                )
            )
        }
    }
    
    @objc private func onMapClick(_ sender: UITapGestureRecognizer) {
        guard sender.state == .ended else { return }
        let screenPoint = sender.location(in: mapView)
        let queryOptions = RenderedQueryOptions(layerIds: layerStyleIds, filter: nil)
        mapView.mapboxMap.queryRenderedFeatures(with: screenPoint, options: queryOptions, completion: { [weak self] result in
            switch result {
            case .success(let features):
                if let feature = features.first?.feature {
                    let dict = feature.properties!.reduce(into: [:]) { $0[$1.0] = $1.1 }
                    self!.annotationData = dict
                    if let geometry = feature.geometry, case let Geometry.point(point) = geometry {
                        self!.targetCoordinate = point.coordinates
                        var customPointAnnotation = PointAnnotation(coordinate: self!.targetCoordinate)
                        if (self!.pointAnnotationManager != nil) {
                            self!.pointAnnotationManager.annotations = []
                        }
                        self!.pointAnnotationManager = self!.mapView.annotations.makePointAnnotationManager()
                        let uuid = NSUUID().uuidString
                        customPointAnnotation.image = .init(image: UIImage(named: "\(dict["clusterName"]!.rawValue) Active")!, name: "\(dict["clusterName"]!.rawValue) Active-\(uuid)")
                        self!.pointAnnotationManager.annotations = [customPointAnnotation]
                        self!.removeSubview()
                        self!.showOverview()
                        switch self!.selectedSegmentIndex {
                        case 1:
                            self!.mapView.mapboxMap.style.uri = StyleURI(rawValue: mapKandangDisableStyleURI)
                        case 2:
                            self!.mapView.mapboxMap.style.uri = StyleURI(rawValue: mapFasilitasStyleURI)
                        default:
                            self!.mapView.mapboxMap.style.uri = StyleURI(rawValue: mapAllDisableStyleURI)
                        }
                    }
                } else {
                    if (self!.pointAnnotationManager != nil) {
                        self!.pointAnnotationManager.annotations = []
                        self!.removeSubview()
                        switch self!.selectedSegmentIndex {
                        case 1:
                            self!.mapView.mapboxMap.style.uri = StyleURI(rawValue: mapKandangDefaultStyleURI)
                        case 2:
                            self!.mapView.mapboxMap.style.uri = StyleURI(rawValue: mapFasilitasStyleURI)
                        default:
                            self!.mapView.mapboxMap.style.uri = StyleURI(rawValue: mapAllDefaultStyleURI)
                        }
                    }
                }
            case .failure(let error):
                print(error.localizedDescription)
            }
        })
    }
    
    func showOverview() {
        let type = annotationData["type"]!.rawValue as? String
        lazy var overviewCardView: OverviewCardView = {
            let oVview = OverviewCardView()
            oVview.translatesAutoresizingMaskIntoConstraints = false
            oVview.tag = 1
            let idName = annotationData["idName"]!.rawValue as? String
            let clusterName = annotationData["clusterName"]!.rawValue as? String
            oVview.title = idName
            oVview.type = type
            oVview.targetCoordinate = targetCoordinate
            
            let imageView = UIImageView(image: UIImage(named: (type == "Kandang" ? idName : clusterName)!))
            imageView.frame = .zero
            imageView.translatesAutoresizingMaskIntoConstraints = false
            oVview.addSubview(imageView)
            
            imageView.anchor(
                bottom: oVview.bottomAnchor,
                left: oVview.rightAnchor,
                paddingBottom: -(type == "Kandang" ? 54 : 10),
                paddingLeft: -(view.bounds.height * ((type == "Kandang" ? 132 : 85) / 844)),
                width: view.bounds.height * ((type == "Kandang" ? 260 : 180) / 844),
                height: view.bounds.height * ((type == "Kandang" ? 260 : 180) / 844)
            )
            
            return oVview
        }()
        
        if type == "Kandang" {
            overviewCardView.overviewButton.addTarget(self, action: #selector(onOverviewClick), for: .touchUpInside)
        } else {
            overviewCardView.startJourneyButton.addTarget(self, action: #selector(onJourneyClick), for: .touchUpInside)
        }
        
        view.addSubview(overviewCardView)
        let safeArea = view.layoutMarginsGuide
        
        overviewCardView.anchor(
            bottom: safeArea.bottomAnchor,
            left: view.leftAnchor,
            right: view.rightAnchor,
            paddingBottom: 20,
            paddingLeft: 16,
            paddingRight: 84,
            height: view.bounds.height * (132 / 844)
        )
    }
    
    @objc private func onOverviewClick(_ sender: UIButton) {
        let animalDetailViewController = AnimalDetailViewController()
        animalDetailViewController.modalPresentationStyle = .fullScreen
        animalDetailViewController.animalData = annotationData
        animalDetailViewController.targetCoordinate = targetCoordinate
        animalDetailViewController.userLocation = userLocation
        self.present(animalDetailViewController, animated: true, completion: nil)
    }
    
    @objc private func onJourneyClick(_ sender: UIButton) {
        startNavigation(targetName: annotationData["idName"]!.rawValue as? String, targetCoordinate: targetCoordinate, userLocation: userLocation)
    }
    
    func removeSubview(){
        if let viewWithTag = self.view.viewWithTag(1) {
            viewWithTag.removeFromSuperview()
        }
    }
    
    func segmentedBackground() {
        view.safeAreaLayoutGuide.owningView?.backgroundColor = .white
        whiteBackground = SegmentedControl.whiteBackground
        view.addSubview(whiteBackground)
        
        // Set the Constraints of the for the Segmented Background Programmatically (With an Array of NSLayoutConstraint)
        NSLayoutConstraint.activate([
            whiteBackground.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            whiteBackground.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            whiteBackground.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            whiteBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -(view.frame.size.height*0.88))
        ])
    }
    
    // MARK: - CUSTOM SEGMENTED CONTROL FUNCTION
    func customSegmentedControl() {
        segmentedBase = SegmentedControl.segmentedBase
        view.addSubview(segmentedBase)
        segmentedButtons = SegmentedControl.segmentedButtons
        let segmentedStackView = SegmentedControl.segmentedStackView
        for button in segmentedButtons {
            button.addTarget(self, action: #selector(segmentedButtonTapped(_:)), for: .touchUpInside)
            segmentedStackView.addArrangedSubview(button)
        }
        segmentedSelector = SegmentedControl.segmentedSelector
        segmentedBase.addSubview(segmentedSelector)
        segmentedBase.addSubview(segmentedStackView)
        
        segmentedStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            segmentedStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: view.frame.size.width*0.04),
            segmentedStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -(view.frame.size.width*0.04)),
            segmentedStackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 56) // 12.5/57 = 0.21
        ])
    }
    
    func setupConstraint() {
        NSLayoutConstraint.activate([
            whiteBackground.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            whiteBackground.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            whiteBackground.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            whiteBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -(view.frame.size.height*0.88)),
            segmentedBase.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: view.frame.size.width*0.04),
            segmentedBase.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -(view.frame.size.width*0.04)),
            segmentedBase.topAnchor.constraint(equalTo: view.topAnchor, constant: 56),
            segmentedBase.heightAnchor.constraint(equalToConstant: 32),
            mapViewRetrieveData.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mapViewRetrieveData.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            mapViewRetrieveData.widthAnchor.constraint(equalToConstant: 200),
            mapViewRetrieveData.heightAnchor.constraint(equalToConstant: 200),
            mapView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            mapView.topAnchor.constraint(equalTo: whiteBackground.bottomAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            searchButton.topAnchor.constraint(equalTo: mapView.topAnchor, constant: 11),
            searchButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -16),
            searchButton.widthAnchor.constraint(equalToConstant: view.bounds.height * (45 / 844)),
            searchButton.heightAnchor.constraint(equalToConstant: view.bounds.height * (45 / 844)),
        ])
    }
    
    // Objective-C Function for the segmentedSelector action
    @objc func segmentedButtonTapped(_ button: UIButton) {
        // buttonIndex = to get the Current index; btn = the Current UIButton
        for (buttonIndex, btn) in segmentedButtons.enumerated() {
            // When the button is not selected, the text color is gray
            btn.setTitleColor(UIColor.SecondaryText, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 17)
            
            // If the button is Clicked
            if btn == button {
                selectedSegmentIndex = buttonIndex
                
                // Animate the segmentedSelector
                let selectorStartPosition = (segmentedBase.frame.width / CGFloat(segmentedButtons.count) * CGFloat(buttonIndex))
                UIView.animate(withDuration: 0.3) {
                    self.segmentedSelector.frame.origin.x = selectorStartPosition
                }
                
                // Change the Selected Text Color to White & Bold
                btn.setTitleColor(.white, for: .normal)
                btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
                if (self.pointAnnotationManager != nil) {
                    self.removeSubview()
                    self.pointAnnotationManager.annotations = []
                }
                // Change the MapView for Each Segmented Control Options
                switch selectedSegmentIndex {
                    // Case 0: If the user select the First Segmented Control Option "Semua" -> See All of the Map Anotations
                case 0:
                    self.mapView.mapboxMap.style.uri = StyleURI(rawValue: mapAllDefaultStyleURI)
                    
                    // Case 1: If the user select the First Segmented Control Option "Kandang" -> See the Cages Only Map Anotations
                case 1:
                    self.mapView.mapboxMap.style.uri = StyleURI(rawValue: mapKandangDefaultStyleURI)
                    
                    // Case 2: If the user select the First Segmented Control Option "Fasilitas" -> See the Facility Only Map Anotations
                case 2:
                    self.mapView.mapboxMap.style.uri = StyleURI(rawValue: mapFasilitasStyleURI)
                    
                    // default: The Default Map -> See All of the Map Anotations
                default:
                    self.mapView.mapboxMap.style.uri = StyleURI(rawValue: mapAllDefaultStyleURI)
                }
                
            }
        }
    }
    
    // MARK: - ANIMATED MONKEY (LOCATION OFF BUTTON FUNCTION)
    func locationOffButton() {
        buttonLocationOFF = MonkeyLocationButton()
        buttonLocationOFF.addTarget(self, action: #selector(buttonLocationOFFAction(_:)), for:.touchUpInside)
        view.addSubview(buttonLocationOFF)
        
        buttonLocationOFF.anchor(
            top: view.safeAreaLayoutGuide.topAnchor,
            left: view.leftAnchor,
            width: 205,
            height: 227
        )
    }
    
    // MARK: - Show the Location Permission After The User Tapped the Monkey Button by Representing the CLLocationManagerDelegate
    @objc func buttonLocationOFFAction(_ button: UIButton) {
        // Give some conditions where the Monkey can be pressed and it will show the location permission
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestAlwaysAuthorization()
    }
    
}

// MARK: - CLLocationManagerDelegate Extension
extension MainViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if ((manager.location?.coordinate) != nil) {
            setupUserLocation()
            userLocation = manager.location!.coordinate
            if self.animalsData.count == 0 || (self.animalsData.count != 0 && self.animalsData.first?.distance == 0) {
                retrieveAnnotationData()
            }
        } else {
            setupUserLocation()
        }
        if status == .authorizedAlways {
            if CLLocationManager.isMonitoringAvailable(for: CLBeaconRegion.self) {
                if CLLocationManager.isRangingAvailable() {
//                    print("THE LOCATION IS ON")
                }
            }
        } else if status == .denied || status == .restricted || status == .authorizedWhenInUse {
            buttonLocationOFF.removeFromSuperview()
        } else if status == .notDetermined {
//            print("User Has Not Determined The Location Permission")
        }
    }
}


import SwiftUI

struct MainViewControllerPreviews: PreviewProvider {
    static var previews: some View {
        UIMainViewControllerPreview {
            return MainViewController()
        }
        .previewDevice("iPhone 13")
    }
}

@available(iOS 13, *)
struct UIMainViewControllerPreview<ViewController: UIViewController>: UIViewControllerRepresentable {
    let viewController: ViewController
    
    init(_ builder: @escaping () -> ViewController) {
        viewController = builder()
    }
    
    func makeUIViewController(context: Context) -> ViewController { viewController }
    
    func updateUIViewController(_ uiViewController: ViewController, context: Context) {}
    
    
}
