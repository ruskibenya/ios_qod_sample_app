//
//  QoDTestViewController.swift
//  Hello-World
//
//  Created by Roberto Perez Cubero on 11/08/16.
//  Copyright 2016 tokbox. All rights reserved.
//

import UIKit
import OpenTok

let kWidgetHeight: CGFloat = 110  // New height
let kWidgetWidth: CGFloat = 147   // New width maintaining aspect ratio (110 * 1.33)

class QoDTestViewController: UIViewController {
    private var videoResult: VideoResultSet?
    private let isCollectingStats: Bool = true  // Hardcoded as discussed
    private var isQoDEnabled: Bool = false  // Track QoD status
    // Scroll view for horizontal subscriber layout
    private lazy var subscribersScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    // Network Quality UI Elements
    private lazy var networkQualityHeaderLabel: UILabel = {
        let label = UILabel()
        label.text = "Network Quality"
        label.font = .systemFont(ofSize: 18, weight: .medium)
        return label
    }()
    
    private lazy var statsView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0) // Light grey background
        view.layer.cornerRadius = 8
        return view
    }()
    
    private lazy var bitrateLabel: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.font = .systemFont(ofSize: 14)
        label.text = "Sent Video Bitrate: -- Kbps"
        return label
    }()
    
    private lazy var packetLossLabel: UILabel = {
        let label = UILabel()
        label.textColor = .black
        label.font = .systemFont(ofSize: 14)
        label.text = "Subscriber Packet Loss: --%"
        return label
    }()
    
    // Stats tracking variables
    private var lastSubscriberBytesReceived: UInt64 = 0
    private var lastSubscriberStatsTimestamp: TimeInterval = 0
    
    // Variables to store the values from the backend
    var kApiKey: String = ""
    var kSessionId: String = ""
    var kToken: String = ""
    
    // MSISDN value passed from HomeViewController
    private let msisdn: String
    private let isHighQuality: Bool
    
    // Initialize with MSISDN and video quality
    init(msisdn: String, isHighQuality: Bool) {
        self.msisdn = msisdn
        self.isHighQuality = isHighQuality
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.msisdn = ""  // Default value when initialized from storyboard
        self.isHighQuality = false  // Default value when initialized from storyboard
        super.init(coder: coder)
    }
    
    // OpenTok objects
    var session: OTSession?
    var publisher: OTPublisher?
    var subscribers: [String: OTSubscriber] = [:] // Changed to dictionary of subscribers
    
    // Add a UIButton property
    var qodButton: UIButton!
    var endTestButton: UIButton!
    
    // Add title label
    var titleLabel: UILabel!
    
    // Timer for RTC stats collection
    private var statsTimer: Timer?
    
    // Section header labels
    var publisherHeaderLabel: UILabel!
    var subscribersHeaderLabel: UILabel!
    
    // Share link elements
    var shareLinkTextView: UITextView!
    
    // QoD Properties
    var sessionStatusTimer: Timer?
    var sessions: [String: Session] = [:]
    
    // QoD Status UI
    private lazy var qodStatusLabel: UILabel = {
        let label = UILabel()
        label.text = "QoD Status"
        label.font = .systemFont(ofSize: 14)
        return label
    }()
    
    private lazy var qodStatusValueLabel: UILabel = {
        let label = UILabel()
        label.text = "Enable QoD to begin..."
        label.font = .systemFont(ofSize: 14, weight: .medium)
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupButtons()
        setupTitleLabel()
        setupSectionHeaders()
    }
    
    // MARK: - RTC Stats Collection
    
    private func startRTCStatsCollection() {
        print("Starting RTC stats collection...")
        // Initialize video result
        videoResult = VideoResultSet(testName: "Video Quality Test")
        
        // Cancel any existing timer
        statsTimer?.invalidate()
        
        // Add a small delay before starting collection
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            print("Initializing RTC stats timer...")
            // Create a new timer that fires every 500ms
            self?.statsTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let self = self,
                      let publisher = self.publisher,
                      !self.subscribers.isEmpty else {
                    print("Skipping stats collection - publisher or subscriber not ready")
                    return
                }
                print("Requesting RTC stats report...")
                publisher.getRtcStatsReport()
                
                // Also collect stats from subscribers
                for subscriber in self.subscribers.values {
                    subscriber.getRtcStatsReport()
                }
            }
        }
    }
    
    private func stopRTCStatsCollection() {
        statsTimer?.invalidate()
        statsTimer = nil
    }
    
    private func updateNetworkQualityPosition() {
        let containerHeight: CGFloat = 80
                
        networkQualityHeaderLabel.frame = CGRect(x: 20,
                                                y: subscribersScrollView.frame.maxY,
                                                width: view.frame.width - 40,
                                                height: 25)
        
        statsView.frame = CGRect(x: 20,
                                 y: networkQualityHeaderLabel.frame.maxY + 5,
                                 width: view.frame.width - 40,
                                 height: containerHeight)
        
        // Add and position stats labels inside container
        let labelPadding: CGFloat = 15
        bitrateLabel.frame = CGRect(x: labelPadding,
                                   y: labelPadding,
                                   width: statsView.frame.width - (2 * labelPadding),
                                   height: 20)
        
        packetLossLabel.frame = CGRect(x: labelPadding,
                                       y: bitrateLabel.frame.maxY + 10,
                                       width: statsView.frame.width - (2 * labelPadding),
                                       height: 20)
    }
    
    private func setupUI() {
        // Set view background color
        view.backgroundColor = .white
        
        // Define consistent spacing values
        let safeAreaTopPadding = view.safeAreaInsets.top
        let titleHeight: CGFloat = 70 // Title section height including padding
        let sectionSpacing: CGFloat = 30 // Consistent spacing between major sections
        let headerHeight: CGFloat = 25 // Height for section headers
        
        // Publisher section measurements
        let publisherStreamHeight = kWidgetHeight
        
        // Calculate stream dimensions for subscribers
        let leftMargin: CGFloat = 20
        let availableWidth = view.frame.width - (leftMargin * 2)
        let streamWidth = (availableWidth - 10) / 2 // Show 2 streams in view
        let aspectRatio = kWidgetWidth / kWidgetHeight
        let streamHeight = streamWidth / aspectRatio
        
        // Calculate vertical positions
        let publisherSectionY = safeAreaTopPadding + titleHeight + sectionSpacing
        let publisherStreamY = publisherSectionY + headerHeight + 10 // Small gap between header and stream
        let subscribersSectionY = publisherStreamY + publisherStreamHeight + sectionSpacing
        let subscribersStreamY = subscribersSectionY + headerHeight + 10
        
        // Position scroll view
        subscribersScrollView.frame = CGRect(x: leftMargin,
                                           y: subscribersStreamY,
                                           width: availableWidth,
                                           height: streamHeight)
        
        // Add views in order
        view.addSubview(subscribersScrollView)
        view.addSubview(statsView)
        
        // Position the stats container view
        let containerHeight: CGFloat = 160 // Increased to accommodate header
        let statsY = subscribersScrollView.frame.origin.y + streamHeight + 60 // Position after scroll view height plus spacing
        statsView.frame = CGRect(x: 20,
                                y: statsY,
                                width: view.frame.width - 40,
                                height: containerHeight)
        
        // Add and position network quality header inside statsView
        statsView.addSubview(networkQualityHeaderLabel)
        networkQualityHeaderLabel.sizeToFit()
        networkQualityHeaderLabel.frame = CGRect(x: 15,
                                                y: 15,
                                                width: statsView.frame.width - 30,
                                                height: headerHeight)
        
        // Add and position stats labels
        statsView.addSubview(qodStatusLabel)
        statsView.addSubview(qodStatusValueLabel)
        statsView.addSubview(bitrateLabel)
        statsView.addSubview(packetLossLabel)
        
        let labelPadding: CGFloat = 15
        
        // Position QoD Status
        qodStatusLabel.frame = CGRect(x: labelPadding,
                                     y: networkQualityHeaderLabel.frame.maxY + 15,
                                     width: 100,
                                     height: 20)
        
        qodStatusValueLabel.frame = CGRect(x: qodStatusLabel.frame.maxX + 5,
                                          y: qodStatusLabel.frame.minY,
                                          width: statsView.frame.width - qodStatusLabel.frame.maxX - labelPadding - 5,
                                          height: 20)
        
        // Position bitrate and packet loss
        bitrateLabel.frame = CGRect(x: labelPadding,
                                   y: qodStatusLabel.frame.maxY + 10,
                                   width: statsView.frame.width - (2 * labelPadding),
                                   height: 20)
        
        packetLossLabel.frame = CGRect(x: labelPadding,
                                       y: bitrateLabel.frame.maxY + 10,
                                       width: statsView.frame.width - (2 * labelPadding),
                                       height: 20)
        
        // Fetch session details from the backend before connecting
        fetchSessionDetails()
    }
    
    private func setupButtons() {
        // Create QoD button
        qodButton = UIButton(type: .system)
        qodButton.setTitle("Enable QoD", for: .normal)
        qodButton.backgroundColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0) // Light blue background
        qodButton.setTitleColor(UIColor.systemBlue, for: .normal)
        qodButton.layer.cornerRadius = 8
        qodButton.addTarget(self, action: #selector(didTapQoDButton), for: .touchUpInside)
        view.addSubview(qodButton)
        
        // Create End Test button
        endTestButton = UIButton(type: .system)
        endTestButton.setTitle("End Test", for: .normal)
        endTestButton.backgroundColor = .black
        endTestButton.setTitleColor(.white, for: .normal)
        endTestButton.layer.cornerRadius = 8
        endTestButton.addTarget(self, action: #selector(handleEndTest), for: .touchUpInside)
        view.addSubview(endTestButton)
        
        // Position buttons at bottom of screen
        let buttonHeight: CGFloat = 44
        let buttonWidth: CGFloat = 120
        let buttonSpacing: CGFloat = 20
        let bottomPadding: CGFloat = 50
        
        endTestButton.frame = CGRect(
            x: (view.frame.width - 2 * buttonWidth - buttonSpacing) / 2,
            y: view.frame.height - bottomPadding - buttonHeight,
            width: buttonWidth,
            height: buttonHeight
        )
        
        qodButton.frame = CGRect(
            x: endTestButton.frame.maxX + buttonSpacing,
            y: endTestButton.frame.minY,
            width: buttonWidth,
            height: buttonHeight
        )
    }
    
    @objc private func handleEndTest() {
        // Stop collecting stats
        stopRTCStatsCollection()
        
        // Push results view controller if we have stats
        if let result = videoResult {
            let resultsVC = TestResultsViewController(videoResult: result)
            navigationController?.pushViewController(resultsVC, animated: true)
        } else {
            print("No stats collected")
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Set up or update the title label position
        setupTitleLabel()
        
        // Set up or update section headers
        setupSectionHeaders()
    }
    
    func setupTitleLabel() {
        if titleLabel == nil {
            titleLabel = UILabel()
            titleLabel.text = "iOS QoD Test"
            titleLabel.textAlignment = .center
            titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .medium)
            view.addSubview(titleLabel)
        }
        
        // Position the label below the safe area
        let safeAreaTopPadding = view.safeAreaInsets.top
        titleLabel.frame = CGRect(x: 20,
                                y: safeAreaTopPadding,
                                width: view.frame.width - 40,
                                height: 30)
        
        // QoD status is now part of the Network Quality section
    }
    
    func setupSectionHeaders() {
        // Publisher header setup
        if publisherHeaderLabel == nil {
            publisherHeaderLabel = UILabel()
            publisherHeaderLabel.text = "Your Video"
            publisherHeaderLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            view.addSubview(publisherHeaderLabel)
        }
        
        // Setup share link text view
        if shareLinkTextView == nil {
            shareLinkTextView = UITextView()
            shareLinkTextView.isEditable = false
            shareLinkTextView.isScrollEnabled = false
            shareLinkTextView.backgroundColor = .clear
            shareLinkTextView.textContainerInset = .zero
            shareLinkTextView.textContainer.lineFragmentPadding = 0
            shareLinkTextView.font = UIFont.systemFont(ofSize: 14)
            shareLinkTextView.text = "" // Initialize with empty text
            view.addSubview(shareLinkTextView)
        }
        
        // Subscribers header setup
        if subscribersHeaderLabel == nil {
            subscribersHeaderLabel = UILabel()
            subscribersHeaderLabel.text = "Participants"
            subscribersHeaderLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            view.addSubview(subscribersHeaderLabel)
        }
        
        // Position the headers
        let safeAreaTopPadding = view.safeAreaInsets.top
        let titleBottom = safeAreaTopPadding + 70 // Title section height including padding
        
        // Position publisher header
        publisherHeaderLabel.frame = CGRect(x: 20,
                                          y: titleBottom,
                                          width: view.frame.width - 40,
                                          height: 25)
        
        // Position share link text view to the right of where publisher video will be
        let publisherRight = 20 + kWidgetWidth + 20 // leftMargin + publisherWidth + spacing
        let shareTextWidth = view.frame.width - publisherRight - 20 // Available width minus right margin
        
        shareLinkTextView.frame = CGRect(x: publisherRight,
                                       y: titleBottom + 25 + 30, // Align with publisher video
                                       width: shareTextWidth,
                                       height: 80)
        
        // Position subscribers header below publisher section
        let publisherStreamHeight = kWidgetHeight
        let headerToStreamSpacing: CGFloat = 20 // Space between header and stream
        let streamToHeaderSpacing: CGFloat = 20 // Space between stream and next header
        
        subscribersHeaderLabel.frame = CGRect(x: 20,
                                            y: titleBottom + headerToStreamSpacing + publisherStreamHeight + streamToHeaderSpacing,
                                            width: view.frame.width - 40,
                                            height: 25)
    }
    
    func handleQoDStatus(with session: Session) {
        var currentStatus: String?

        if let updateStatus = session.update?.status {
            currentStatus = updateStatus
            qodStatusValueLabel.text = updateStatus
            isQoDEnabled = (updateStatus == "ACTIVE")
            print("QoD Status updated to: \(updateStatus), QoD Enabled: \(isQoDEnabled)")
        } else if let statuses = session.channels.first?.statuses, let lastStatus = statuses.last {
            currentStatus = lastStatus.status
            qodStatusValueLabel.text = lastStatus.status
            isQoDEnabled = (lastStatus.status == "ACTIVE")
            print("QoD Status updated to: \(lastStatus.status), QoD Enabled: \(isQoDEnabled)")
        } else {
            qodStatusValueLabel.text = "Status Unknown"
            print("No QoD status available in session data.")
        }

        // Re-enable the button if the status is "COMPLETED" or "FAILED"
        if currentStatus == "COMPLETED" || currentStatus == "FAILED" {
            qodButton.isEnabled = true
            qodButton.alpha = 1.0
        }
    }
    
    // Function to set up the QoD button
    func setupQodButton() {
        // Initialize the button
        qodButton = UIButton(type: .system)
        qodButton.frame = CGRect(x: 20, y: self.view.frame.height - 80, width: self.view.frame.width - 40, height: 60)
        qodButton.setTitle("Send QoD Request", for: .normal)
        qodButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        qodButton.backgroundColor = UIColor.systemBlue
        qodButton.setTitleColor(.white, for: .normal)
        qodButton.layer.cornerRadius = 10
        
        // Add target-action for the button
        qodButton.addTarget(self, action: #selector(didTapQoDButton), for: .touchUpInside)
        
        // Add the button to the view
        view.addSubview(qodButton)
    }
    
    // Action method called when the QoD button is pressed
    @objc func didTapQoDButton() {
        // Disable the button
        qodButton.isEnabled = false

        // Optionally, change the button's appearance when disabled
        qodButton.alpha = 0.5
        
        // Update layout to accommodate newly visible section
        layoutSubscribers()
        
        // Send the POST request to the /qod endpoint
        sendQodRequest()
    }
    
    func fetchSessionById(_ sessionId: String) {
        let urlString = "https://neru-b6ae7ba7-vonage-video-backend-server-dev.euw1.runtime.vonage.cloud/qod-sessions/\(sessionId)"
        guard let url = URL(string: urlString) else { return }
        
        // Create the URL request
        let request = URLRequest(url: url)
        
        // Perform the network request
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Error fetching session: \(error)")
                return
            }
            
            guard let data = data else {
                print("No data returned")
                return
            }
            
            // Decode the JSON response
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase  // Handle snake_case keys
                
                let session = try decoder.decode(Session.self, from: data)
                
                // Update the sessions dictionary on the main thread
                DispatchQueue.main.async {
                    self?.sessions[sessionId] = session
                    
                    // Update the UI
                    self?.handleQoDStatus(with: session)
                    
                    // Start polling for session status updates
                    self?.startSessionStatusPolling(sessionId: sessionId)
                }
            } catch let jsonError {
                print("Failed to decode JSON: \(jsonError)")
                
                // For debugging, print the response as a string
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response String: \(responseString)")
                }
            }
        }
        
        // Start the task
        task.resume()
    }
    
    // Function to send the POST request to the /qod endpoint
    func sendQodRequest() {
        // Endpoint URL
        let urlString = "https://neru-b6ae7ba7-vonage-video-backend-server-dev.euw1.runtime.vonage.cloud/qod" //update to user's VCR url
        guard let url = URL(string: urlString) else { return }
        
        // Prepare the JSON data
        let parameters: [String: Any] = [
            "phone_number": msisdn  // Use the msisdn value passed from HomeViewController
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: []) else {
            print("Failed to serialize JSON")
            return
        }
        
        // Create the URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = httpBody
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Perform the network request
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Error making POST request: \(error)")
                return
            }
            
            guard let data = data else {
                print("No data returned from POST request")
                return
            }
            
            // Handle the response data
            do {
                // Parse the JSON response
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let sessionId = json["id"] as? String {
                    print("Session ID: \(sessionId)")
                    
                    // Fetch the session data using the session ID
                    self?.fetchSessionById(sessionId)
                } else {
                    print("Failed to parse JSON or 'id' not found")
                }
            } catch let jsonError {
                print("Failed to parse JSON response: \(jsonError)")
                
                // For debugging, print the response as a string
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response String: \(responseString)")
                }
            }
        }
        
        // Start the task
        task.resume()
    }
    
    func startSessionStatusPolling(sessionId: String) {
        // Invalidate existing timer if any
        sessionStatusTimer?.invalidate()
        
        print("Starting session status polling for sessionId: \(sessionId)")
        
        DispatchQueue.main.async { [weak self] in
            // Start a new timer on the main run loop
            self?.sessionStatusTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                self?.fetchSessionStatus(sessionId: sessionId)
            }
        }
    }

    // Rename to Video Session
    func fetchSessionStatus(sessionId: String) {
        print("Fetching session status for sessionId: \(sessionId)")
        let urlString = "https://neru-b6ae7ba7-vonage-video-backend-server-dev.euw1.runtime.vonage.cloud/qod-sessions/\(sessionId)"
        guard let url = URL(string: urlString) else { return }
        
        let request = URLRequest(url: url)
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Error fetching session status: \(error)")
                return
            }
            
            guard let data = data else {
                print("No data returned")
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                let session = try decoder.decode(Session.self, from: data)
                
                print("The session looks like: \(session)")
                
                // Update the sessions dictionary
                DispatchQueue.main.async {
                    self?.sessions[sessionId] = session
                    self?.handleQoDStatus(with: session)
                    
                    // Check if status is final, e.g., 'COMPLETED' or 'FAILED', and stop polling
                    if let status = session.update?.status {
                        print("Current session status from update: \(status)")
                        if status == "COMPLETED" || status == "FAILED" {
                            // Stop polling
                            self?.sessionStatusTimer?.invalidate()
                            self?.sessionStatusTimer = nil
                        }
                    } else if let statuses = session.channels.first?.statuses, let lastStatus = statuses.last {
                        let status = lastStatus.status
                        print("Current session status from channels: \(status)")
                        if status == "COMPLETED" || status == "FAILED" {
                            // Stop polling
                            self?.sessionStatusTimer?.invalidate()
                            self?.sessionStatusTimer = nil
                        }
                    }
                }
            } catch let jsonError {
                print("Failed to decode JSON: \(jsonError)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response String: \(responseString)")
                }
            }
        }
        task.resume()
    }
    
    private func updateSubscribersHeaderLabel() {
        let count = subscribers.count
        subscribersHeaderLabel.text = count > 0 ? "Participants (\(count))" : "Participants"
    }
    
    func cleanupSubscriber() {
        subscribers.values.forEach { subscriber in
            subscriber.view?.removeFromSuperview()
        }
        subscribers.removeAll()
        updateSubscribersHeaderLabel()
    }
    
    fileprivate func doSubscribe(_ stream: OTStream) {
        var error: OTError?
        guard let subscriber = OTSubscriber(stream: stream, delegate: self) else {
            print("Failed to create subscriber")
            return
        }
        
        defer {
            processError(error)
        }
        
        subscriber.rtcStatsReportDelegate = self
        session?.subscribe(subscriber, error: &error)
        if error == nil {
            subscribers[stream.streamId] = subscriber
            layoutSubscribers()
            updateSubscribersHeaderLabel()
        }
    }
    
    private func layoutSubscribers() {
        // Get layout parameters
        let safeAreaTopPadding = view.safeAreaInsets.top
        let titleHeight: CGFloat = 70 // Title section height including padding
        let publisherHeaderHeight: CGFloat = 25 // Publisher header height
        let headerBottomPadding: CGFloat = 20 // Padding below headers
        let publisherStreamHeight = kWidgetHeight
        let headerToStreamSpacing: CGFloat = 10 // Space between header and stream
        let streamToHeaderSpacing: CGFloat = 20 // Space between stream and next header
        let leftMargin: CGFloat = 20 // Match header label left margin
        let streamSpacing: CGFloat = 10 // Spacing between subscriber streams
        
        // Calculate base Y position for scroll view
        let scrollViewY = safeAreaTopPadding + titleHeight + publisherHeaderHeight + headerBottomPadding + publisherStreamHeight + headerToStreamSpacing + streamToHeaderSpacing 
        
        // Calculate stream dimensions
        let availableWidth = view.frame.width - (leftMargin * 2)
        let streamWidth = (availableWidth - streamSpacing) / 2 // Show 2 streams in view
        let aspectRatio = kWidgetWidth / kWidgetHeight
        let streamHeight = streamWidth / aspectRatio
        
        // Setup scroll view if not already added
        if subscribersScrollView.superview == nil {
            view.addSubview(subscribersScrollView)
        }
        
        // Position scroll view
        subscribersScrollView.frame = CGRect(x: leftMargin,
                                           y: scrollViewY,
                                           width: availableWidth,
                                           height: streamHeight)
        
        // Layout subscribers horizontally
        let subscriberArray = Array(subscribers.values)
        var contentWidth: CGFloat = 0
        
        // Remove any existing subscriber views from scroll view
        subscribersScrollView.subviews.forEach { $0.removeFromSuperview() }
        
        for (index, subscriber) in subscriberArray.enumerated() {
            if let subsView = subscriber.view {
                let x = CGFloat(index) * (streamWidth + streamSpacing)
                
                subsView.frame = CGRect(x: x,
                                      y: 0,
                                      width: streamWidth,
                                      height: streamHeight)
                
                subscribersScrollView.addSubview(subsView)
                
                // Update content width
                contentWidth = x + streamWidth
            }
        }
        
        // Set scroll view content size
        subscribersScrollView.contentSize = CGSize(width: contentWidth + streamSpacing,
                                                 height: streamHeight)
        
    }
    
    fileprivate func doPublish() {
        var error: OTError?
        defer {
            processError(error)
        }
        
        let settings = OTPublisherSettings()
        settings.name = UIDevice.current.name
        
        // Configure high quality video if enabled
        if isHighQuality {
            print("Configuring high quality video (1080p)")
            settings.cameraResolution = .high1080p // This corresponds to true 1080p (1920x1080)
            settings.cameraFrameRate = .rate30FPS
        } else {
            print("Configuring medium quality video (640x480)")
            settings.cameraResolution = .medium // Default to medium quality (640x480)
            settings.cameraFrameRate = .rate30FPS
        }
        
        print("Publisher settings: resolution=\(settings.cameraResolution.rawValue), framerate=\(settings.cameraFrameRate.rawValue)")
        
        guard let pub = OTPublisher(delegate: self, settings: settings) else {
            return
        }
        publisher = pub
        pub.rtcStatsReportDelegate = self
        
        session?.publish(pub, error: &error)
        
        guard error == nil else {
            print("Publish error: \(error!.localizedDescription)")
            return
        }
        
        layoutPublisherView()
    }
    
    fileprivate func layoutPublisherView() {
        // Position the publisher view below the title
        let safeAreaTopPadding = view.safeAreaInsets.top
        let titleHeight: CGFloat = 70 // Title section height including padding
        let publisherHeaderHeight: CGFloat = 25 // Publisher header height
        let headerToStreamSpacing: CGFloat = 10 // Increased from 10 to 30
        let leftMargin: CGFloat = 20 // Match header label left margin
        
        if let pubView = publisher?.view {
            pubView.frame = CGRect(x: leftMargin, 
                                 y: safeAreaTopPadding + titleHeight + publisherHeaderHeight + headerToStreamSpacing,
                                 width: kWidgetWidth, 
                                 height: kWidgetHeight)
            view.addSubview(pubView)
        }
    }
    
    /**
     * Sets up an instance of OTPublisher to use with this session.
     */
    
    /**
     * Asynchronously begins the session connect process. Some time later, we will
     * expect a delegate method to call us back with the results of this action.
     */
    fileprivate func doConnect() {
        var error: OTError?
        defer {
            processError(error)
        }
        
        guard let session = session else {
            print("Session not initialized")
            return
        }
        
        session.connect(withToken: kToken, error: &error)
    }
    
    /**
     * Sets up an instance of OTPublisher to use with this session.
     */
    
    fileprivate func processError(_ error: OTError?) {
        if let err = error {
            DispatchQueue.main.async {
                let controller = UIAlertController(title: "Error", message: err.localizedDescription, preferredStyle: .alert)
                controller.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                self.present(controller, animated: true, completion: nil)
            }
        }
    }
    
    fileprivate func cleanupPublisher() {
        publisher?.view?.removeFromSuperview()
        publisher = nil
    }
    
    func fetchSessionDetails() {
        // Endpoint URL
        let urlString = "https://neru-b6ae7ba7-vonage-video-backend-server-dev.euw1.runtime.vonage.cloud/room/test"
        guard let url = URL(string: urlString) else { return }
        
        // Create the URL request
        let request = URLRequest(url: url)
        
        // Perform the network request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching session details: \(error)")
                return
            }
            
            guard let data = data else {
                print("No data returned")
                return
            }
            
            // Decode the JSON response
            do {
                let sessionResponse = try JSONDecoder().decode(SessionResponse.self, from: data)
                
                // Update the variables on the main thread
                DispatchQueue.main.async {
                    self.kApiKey = sessionResponse.applicationId
                    self.kSessionId = sessionResponse.sessionId
                    self.kToken = sessionResponse.token
                    
                    // After fetching the details, initialize the OpenTok session
                    self.session = OTSession(apiKey: self.kApiKey, sessionId: self.kSessionId, delegate: self)
                    print("session: \(self.kSessionId)")
                    print("token: \(self.kToken)")
                    
                    // Now connect to the session
                    self.doConnect()
                }
            } catch let jsonError {
                print("Failed to decode JSON: \(jsonError)")
            }
        }
        
        // Start the task
        task.resume()
    }
}

// MARK: - OTSession delegate callbacks
extension QoDTestViewController: OTSessionDelegate {
    func sessionDidConnect(_ session: OTSession) {
        print("Session connected")
        doPublish()
        updateShareLinkText()
    }
    
    func sessionDidDisconnect(_ session: OTSession) {
        print("Session disconnected")
        stopRTCStatsCollection()
        cleanupSubscriber()
        cleanupPublisher()
    }
    
    func session(_ session: OTSession, streamCreated stream: OTStream) {
        print("Session streamCreated: \(stream.streamId)")
        doSubscribe(stream)
    }
    
    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        print("Session streamDestroyed: \(stream.streamId)")
        if let subscriber = subscribers[stream.streamId] {
            subscriber.view?.removeFromSuperview()
            subscribers.removeValue(forKey: stream.streamId)
            layoutSubscribers() // Relayout remaining subscribers
        }
    }
    
    func session(_ session: OTSession, didFailWithError error: OTError) {
        print("Session failed to connect: \(error.localizedDescription)")
    }
}

// MARK: - OTPublisher delegate callbacks
// MARK: - RTC Stats Report Delegates
extension QoDTestViewController: OTPublisherKitRtcStatsReportDelegate, OTSubscriberKitRtcStatsReportDelegate {
    private func processRTCStats(_ jsonArrayOfReports: String, isPublisher: Bool) {
        print("Processing RTC stats for \(isPublisher ? "Publisher" : "Subscriber")")
        guard let data = jsonArrayOfReports.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            print("Failed to parse RTC stats JSON")
            return
        }
        
        var currentRoundTripTimeMs: Double = 0.0
        var videoStats: [String: Any]? = nil
        
        // First pass: Look for the nominated candidate pair to get RTT
        for report in jsonArray {
            if let type = report["type"] as? String {
                switch type {
                case "candidate-pair":
                    if let isNominated = report["nominated"] as? Bool, isNominated {
                        currentRoundTripTimeMs = (report["currentRoundTripTime"] as? Double ?? 0.0) * 1000
                    }
                case "inbound-rtp" where !isPublisher:
                    if let kind = report["kind"] as? String, kind == "video" {
                        videoStats = report
                    }
                default:
                    break
                }
            }
        }
        
        // Process video stats for subscriber
        if !isPublisher, let stats = videoStats {
            if let timestamp = stats["timestamp"] as? TimeInterval,
               let bytesReceived = stats["bytesReceived"] as? UInt64 {
                
                // Calculate bitrate if we have previous values
                var videoBitrateKbps: Double = 0.0
                if lastSubscriberStatsTimestamp > 0 {
                    let elapsedTimeMs = timestamp - lastSubscriberStatsTimestamp
                    // Handle potential overflow by converting to Double before multiplication
                    let bytesReceivedDiff = Double(bytesReceived) - Double(lastSubscriberBytesReceived)
                    // Avoid division by zero and ensure proper order of operations
                    if elapsedTimeMs > 0 {
                        videoBitrateKbps = (bytesReceivedDiff * 8.0 / elapsedTimeMs) * 1000.0 / 1000.0
                    }
                }
                
                // Get packet loss stats
                let packetsLost = stats["packetsLost"] as? UInt32 ?? 0
                let packetsReceived = stats["packetsReceived"] as? UInt32 ?? 0
                
                // Calculate packet loss ratio
                let totalPackets = Double(packetsReceived + packetsLost)
                let packetLossRatio = totalPackets > 0 ? Double(packetsLost) / totalPackets : 0.0
                
                // Store stats in videoResult if we're collecting
                if isCollectingStats {
                    let videoStats = VideoStats(
                        timestamp: timestamp,
                        videoBitrateKbps: videoBitrateKbps,
                        packetLossRatio: packetLossRatio,
                        qodEnabled: isQoDEnabled
                    )
                    videoResult?.qualityStats.append(videoStats)
                }
                
                // Update UI on main thread
                DispatchQueue.main.async { [weak self] in
                    self?.bitrateLabel.text = "Sent Video Bitrate: \(String(format: "%.0f", videoBitrateKbps)) Kbps"
                    self?.packetLossLabel.text = "Subscriber Packet Loss: \(String(format: "%.1f", packetLossRatio * 100))%"
                }
                
                // Update values for next calculation
                lastSubscriberBytesReceived = bytesReceived
                lastSubscriberStatsTimestamp = timestamp
            }
        }
    }
    
    func publisher(_ publisher: OTPublisherKit, rtcStatsReport jsonArrayOfReports: String) {
        processRTCStats(jsonArrayOfReports, isPublisher: true)
    }
    
    func subscriber(_ subscriber: OTSubscriberKit, rtcStatsReport jsonArrayOfReports: String) {
        processRTCStats(jsonArrayOfReports, isPublisher: false)
    }
}

// MARK: - OTPublisherDelegate
extension QoDTestViewController: OTPublisherDelegate {
    func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
        print("Publishing stream created: \(stream.streamId)")
    }
    
    func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {
        print("Publisher stream destroyed: \(stream.streamId)")
        stopRTCStatsCollection()
        cleanupPublisher()
        if let subStream = subscribers.first?.value.stream, subStream.streamId == stream.streamId {
            cleanupSubscriber()
        }
    }
    
    func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
        print("Publisher failed: \(error.localizedDescription)")
        stopRTCStatsCollection()
    }
}

// MARK: - OTSubscriber delegate callbacks
extension QoDTestViewController: OTSubscriberDelegate {
    func subscriberDidConnect(toStream subscriberKit: OTSubscriberKit) {
        print("Subscriber connected - starting RTC stats collection")
        startRTCStatsCollection()
        layoutSubscribers()
    }
    
    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print("Subscriber failed: \(error.localizedDescription)")
    }
}

// Struct to map the JSON response
struct SessionResponse: Codable {
    let applicationId: String
    let sessionId: String
    let token: String
}

extension QoDTestViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        UIApplication.shared.open(URL)
        return false
    }
}

extension QoDTestViewController {
    private func updateShareLinkText() {
        let shareText = "Share the link for more participants to join the call:"
        let displayText = "Vonage Video API Playground"
        let linkUrl = "https://tools.vonage.com/video/playground/connect?v=2.29&sessionId=\(kSessionId)"
        
        let attributedString = NSMutableAttributedString(string: shareText + "\n\n" + displayText)
        
        // Calculate the range for the link
        let fullText = attributedString.string
        if let linkRange = fullText.range(of: displayText) {
            let nsRange = NSRange(linkRange, in: fullText)
            attributedString.addAttribute(.link,
                                        value: linkUrl,
                                        range: nsRange)
        }
        
        shareLinkTextView.attributedText = attributedString
        shareLinkTextView.delegate = self
    }
}
