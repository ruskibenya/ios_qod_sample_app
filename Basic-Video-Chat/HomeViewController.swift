import UIKit

class HomeViewController: UIViewController {
    // MARK: - Properties
    private var msisdn: String = ""
    private var isHighQuality: Bool = false
    
    // MARK: - UI Elements
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.95, alpha: 1.0) // Light gray background
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "iOS QoD Sample App"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 24, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleTextView: UITextView = {
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.backgroundColor = .clear
        textView.textAlignment = .center
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        let text = "Check out the QoD API Documentation."
        let attributedString = NSMutableAttributedString(string: text)
        
        if let range = text.range(of: "QoD API Documentation") {
            let nsRange = NSRange(range, in: text)
            let url = URL(string: "https://developer.vonage.com/en/qod/overview")!
            attributedString.addAttribute(.link, value: url, range: nsRange)
        }
        
        textView.attributedText = attributedString
        textView.font = .systemFont(ofSize: 16)
        textView.textColor = .black
        textView.textAlignment = .center
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.black,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        
        return textView
    }()
    
    private let msisdnTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "MSISDN"
        textField.borderStyle = .roundedRect
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.keyboardType = .numberPad
        return textField
    }()
    
    private let toggleContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.layer.cornerRadius = 8
        return view
    }()
    
    private let toggleLabel: UILabel = {
        let label = UILabel()
        label.text = "Publish 1080p video"
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let qualityToggle: UISwitch = {
        let toggle = UISwitch()
        toggle.translatesAutoresizingMaskIntoConstraints = false
        return toggle
    }()
    
    private let startButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Start Network Test", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .white
        
        view.addSubview(titleLabel)
        view.addSubview(subtitleTextView)
        view.addSubview(containerView)
        view.addSubview(startButton)
        
        containerView.addSubview(msisdnTextField)
        containerView.addSubview(toggleContainer)
        
        toggleContainer.addSubview(toggleLabel)
        toggleContainer.addSubview(qualityToggle)
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            
            subtitleTextView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleTextView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            subtitleTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subtitleTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            containerView.topAnchor.constraint(equalTo: subtitleTextView.bottomAnchor, constant: 30),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            msisdnTextField.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            msisdnTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            msisdnTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            msisdnTextField.heightAnchor.constraint(equalToConstant: 44),
            
            toggleContainer.topAnchor.constraint(equalTo: msisdnTextField.bottomAnchor, constant: 20),
            toggleContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            toggleContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            toggleContainer.heightAnchor.constraint(equalToConstant: 44),
            toggleContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
            
            toggleLabel.leadingAnchor.constraint(equalTo: toggleContainer.leadingAnchor, constant: 16),
            toggleLabel.centerYAnchor.constraint(equalTo: toggleContainer.centerYAnchor),
            
            qualityToggle.trailingAnchor.constraint(equalTo: toggleContainer.trailingAnchor, constant: -16),
            qualityToggle.centerYAnchor.constraint(equalTo: toggleContainer.centerYAnchor),
            
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 30),
            startButton.widthAnchor.constraint(equalToConstant: 250),
            startButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupActions() {
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        msisdnTextField.addTarget(self, action: #selector(msisdnTextFieldChanged), for: .editingChanged)
        qualityToggle.addTarget(self, action: #selector(qualityToggleChanged), for: .valueChanged)
    }
    
    // MARK: - Actions
    @objc private func msisdnTextFieldChanged() {
        msisdn = msisdnTextField.text ?? ""
    }
    
    @objc private func qualityToggleChanged() {
        isHighQuality = qualityToggle.isOn
    }
    
    @objc private func startButtonTapped() {
        print("Form submitted with values:")
        print("MSISDN: \(msisdn)")
        print("1080p enabled: \(isHighQuality)")
        
        // Create QoDTestViewController with MSISDN and video quality settings
        let viewController = QoDTestViewController(msisdn: msisdn, isHighQuality: isHighQuality)
        navigationController?.pushViewController(viewController, animated: true)
    }
}
