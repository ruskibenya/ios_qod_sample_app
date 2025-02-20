import UIKit
import DGCharts

class DateValueFormatter: AxisValueFormatter {
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let date = Date(timeIntervalSince1970: value)
        return dateFormatter.string(from: date)
    }
}

class TestResultsViewController: UIViewController {
    private let videoResult: VideoResultSet
    
    // UI Elements
    private var titleLabel: UILabel!
    
    // Chart Views
    private let bitrateChartTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Video Bitrate (Kbps)"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        return label
    }()
    
    private let bitrateChartView: LineChartView = {
        let chartView = LineChartView()
        chartView.rightAxis.enabled = false
        chartView.xAxis.labelPosition = .bottom
        chartView.xAxis.labelRotationAngle = 0
        chartView.xAxis.valueFormatter = DateValueFormatter()
        chartView.leftAxis.labelPosition = .outsideChart
        chartView.leftAxis.axisMinimum = 0
        chartView.dragEnabled = true
        chartView.pinchZoomEnabled = true
        chartView.doubleTapToZoomEnabled = true
        chartView.chartDescription.enabled = false  // Disable default description
        return chartView
    }()
    
    private let packetLossChartTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Packet Loss Ratio"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        return label
    }()
    
    private let packetLossChartView: LineChartView = {
        let chartView = LineChartView()
        chartView.rightAxis.enabled = false
        chartView.xAxis.labelPosition = .bottom
        chartView.xAxis.labelRotationAngle = 0
        chartView.xAxis.valueFormatter = DateValueFormatter()
        chartView.leftAxis.labelPosition = .outsideChart
        chartView.leftAxis.axisMinimum = 0
        chartView.leftAxis.axisMaximum = 1
        chartView.dragEnabled = true
        chartView.pinchZoomEnabled = true
        chartView.doubleTapToZoomEnabled = true
        chartView.chartDescription.enabled = false  // Disable default description
        return chartView
    }()
    
    private lazy var startOverButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Start Over", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18)
        button.backgroundColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(startOverTapped), for: .touchUpInside)
        return button
    }()
    
    init(videoResult: VideoResultSet) {
        self.videoResult = videoResult
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCharts()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        // Setup title
        titleLabel = UILabel()
        titleLabel.text = "Test Results"
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        view.addSubview(titleLabel)
        
        // Setup charts and their titles
        view.addSubview(bitrateChartTitleLabel)
        view.addSubview(bitrateChartView)
        view.addSubview(packetLossChartTitleLabel)
        view.addSubview(packetLossChartView)
        
        // Setup start over button
        view.addSubview(startOverButton)
        
        // Configure auto layout
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        bitrateChartTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        bitrateChartView.translatesAutoresizingMaskIntoConstraints = false
        packetLossChartTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        packetLossChartView.translatesAutoresizingMaskIntoConstraints = false
        startOverButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Title constraints
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Bitrate chart title constraints
            bitrateChartTitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            bitrateChartTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            bitrateChartTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Bitrate chart constraints
            bitrateChartView.topAnchor.constraint(equalTo: bitrateChartTitleLabel.bottomAnchor, constant: 8),
            bitrateChartView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            bitrateChartView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            bitrateChartView.heightAnchor.constraint(equalToConstant: 200),
            
            // Packet loss chart title constraints
            packetLossChartTitleLabel.topAnchor.constraint(equalTo: bitrateChartView.bottomAnchor, constant: 20),
            packetLossChartTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            packetLossChartTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Packet loss chart constraints
            packetLossChartView.topAnchor.constraint(equalTo: packetLossChartTitleLabel.bottomAnchor, constant: 8),
            packetLossChartView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            packetLossChartView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            packetLossChartView.heightAnchor.constraint(equalToConstant: 200),
            
            // Start over button constraints
            startOverButton.topAnchor.constraint(equalTo: packetLossChartView.bottomAnchor, constant: 20),
            startOverButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            startOverButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            startOverButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            startOverButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func startOverTapped() {
        // Pop to root view controller (HomeViewController)
        navigationController?.popToRootViewController(animated: true)
    }
    
    private func setupCharts() {
        // Print QoD status for each data point
        print("\nTest Results with QoD Status:")
        videoResult.qualityStats.forEach { stat in
            print("Time: \(Date(timeIntervalSince1970: stat.timestamp / 1000)), " +
                  "Bitrate: \(String(format: "%.1f", stat.videoBitrateKbps)) Kbps, " +
                  "Packet Loss: \(String(format: "%.3f", stat.packetLossRatio)), " +
                  "QoD Enabled: \(stat.qodEnabled)")
        }
        
        // Setup bitrate chart data - separate QoD enabled and disabled points
        let bitrateEntriesQoDEnabled = videoResult.qualityStats.enumerated().compactMap { (index, stat) -> ChartDataEntry? in
            return stat.qodEnabled ? ChartDataEntry(x: stat.timestamp / 1000, y: stat.videoBitrateKbps) : nil
        }
        
        let bitrateEntriesQoDDisabled = videoResult.qualityStats.enumerated().compactMap { (index, stat) -> ChartDataEntry? in
            return !stat.qodEnabled ? ChartDataEntry(x: stat.timestamp / 1000, y: stat.videoBitrateKbps) : nil
        }
        
        let bitrateDataSetQoDEnabled = LineChartDataSet(entries: bitrateEntriesQoDEnabled, label: "QoD On")
        bitrateDataSetQoDEnabled.drawCirclesEnabled = false
        bitrateDataSetQoDEnabled.mode = .linear
        bitrateDataSetQoDEnabled.lineWidth = 2
        bitrateDataSetQoDEnabled.setColor(.systemRed)
        bitrateDataSetQoDEnabled.fillAlpha = 0.3
        bitrateDataSetQoDEnabled.drawFilledEnabled = true
        bitrateDataSetQoDEnabled.drawValuesEnabled = false
        
        let bitrateDataSetQoDDisabled = LineChartDataSet(entries: bitrateEntriesQoDDisabled, label: "QoD Off")
        bitrateDataSetQoDDisabled.drawCirclesEnabled = false
        bitrateDataSetQoDDisabled.mode = .linear
        bitrateDataSetQoDDisabled.lineWidth = 2
        bitrateDataSetQoDDisabled.setColor(.systemBlue)
        bitrateDataSetQoDDisabled.fillAlpha = 0.3
        bitrateDataSetQoDDisabled.drawFilledEnabled = true
        bitrateDataSetQoDDisabled.drawValuesEnabled = false
        
        let bitrateData = LineChartData(dataSets: [bitrateDataSetQoDDisabled, bitrateDataSetQoDEnabled])
        bitrateChartView.data = bitrateData
        bitrateChartView.animate(xAxisDuration: 1.0)
        
        // Setup packet loss chart data - separate QoD enabled and disabled points
        let packetLossEntriesQoDEnabled = videoResult.qualityStats.enumerated().compactMap { (index, stat) -> ChartDataEntry? in
            return stat.qodEnabled ? ChartDataEntry(x: stat.timestamp / 1000, y: stat.packetLossRatio) : nil
        }
        
        let packetLossEntriesQoDDisabled = videoResult.qualityStats.enumerated().compactMap { (index, stat) -> ChartDataEntry? in
            return !stat.qodEnabled ? ChartDataEntry(x: stat.timestamp / 1000, y: stat.packetLossRatio) : nil
        }
        
        let packetLossDataSetQoDEnabled = LineChartDataSet(entries: packetLossEntriesQoDEnabled, label: "QoD On")
        packetLossDataSetQoDEnabled.drawCirclesEnabled = false
        packetLossDataSetQoDEnabled.mode = .linear
        packetLossDataSetQoDEnabled.lineWidth = 2
        packetLossDataSetQoDEnabled.setColor(.systemGreen)
        packetLossDataSetQoDEnabled.fillAlpha = 0.3
        packetLossDataSetQoDEnabled.drawFilledEnabled = true
        packetLossDataSetQoDEnabled.drawValuesEnabled = false
        
        let packetLossDataSetQoDDisabled = LineChartDataSet(entries: packetLossEntriesQoDDisabled, label: "QoD Off")
        packetLossDataSetQoDDisabled.drawCirclesEnabled = false
        packetLossDataSetQoDDisabled.mode = .linear
        packetLossDataSetQoDDisabled.lineWidth = 2
        packetLossDataSetQoDDisabled.setColor(.systemOrange)
        packetLossDataSetQoDDisabled.fillAlpha = 0.3
        packetLossDataSetQoDDisabled.drawFilledEnabled = true
        packetLossDataSetQoDDisabled.drawValuesEnabled = false
        
        let packetLossData = LineChartData(dataSets: [packetLossDataSetQoDDisabled, packetLossDataSetQoDEnabled])
        packetLossChartView.data = packetLossData
        packetLossChartView.animate(xAxisDuration: 1.0)
    }
}
