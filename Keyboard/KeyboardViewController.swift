import UIKit

/// iOS keyboard extension: local-only Zhuyin input using UITextDocumentProxy.
final class KeyboardViewController: UIInputViewController {
    private enum Mode { case zhuyin, numbers, symbols, english }
    private var mode: Mode = .zhuyin
    private var engine = ZhuyinEngine()
    private lazy var lexicon = PhoneticLexicon(bundle: .main)
    private var selectedGroup: Int?
    private let candidateScroll = UIScrollView()
    private let candidateStack = UIStackView()
    private let typedLabel = UILabel()
    private let grid = UIStackView()
    private let numberButton = UIButton(type: .system)
    private let spaceButton = UIButton(type: .system)
    private let background = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.16, alpha: 1) : UIColor(red: 0.83,green: 0.85,blue: 0.89,alpha: 1) }
    private let keyBackground = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.28,alpha: 1) : .white }
    private let secondaryBackground = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.35,alpha: 1) : UIColor(red: 0.69,green: 0.72,blue: 0.77,alpha: 1) }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = background
        build()
        refresh()
    }
    private func build() {
        let fixedHeight = view.heightAnchor.constraint(equalToConstant: 340)
        fixedHeight.priority = .defaultHigh
        fixedHeight.isActive = true
        let root = UIStackView()
        root.axis = .vertical
        root.spacing = 5
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 5),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -5),
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 5),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -5)
        ])
        let bar = UIStackView()
        bar.axis = .horizontal
        bar.spacing = 6
        bar.alignment = .center
        typedLabel.font = .systemFont(ofSize: 15,weight: .medium)
        typedLabel.textColor = .label
        typedLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 104).isActive = true
        typedLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        bar.addArrangedSubview(typedLabel)
        candidateScroll.showsHorizontalScrollIndicator = false
        candidateStack.axis = .horizontal
        candidateStack.spacing = 5
        candidateStack.alignment = .center
        candidateStack.translatesAutoresizingMaskIntoConstraints = false
        candidateScroll.addSubview(candidateStack)
        NSLayoutConstraint.activate([
            candidateStack.topAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.topAnchor),
            candidateStack.bottomAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.bottomAnchor),
            candidateStack.leadingAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.leadingAnchor),
            candidateStack.trailingAnchor.constraint(equalTo: candidateScroll.contentLayoutGuide.trailingAnchor),
            candidateStack.heightAnchor.constraint(equalTo: candidateScroll.frameLayoutGuide.heightAnchor)
        ])
        bar.addArrangedSubview(candidateScroll)
        bar.heightAnchor.constraint(equalToConstant: 42).isActive = true
        root.addArrangedSubview(bar)

        let tones = UIStackView()
        tones.axis = .horizontal
        tones.distribution = .fillEqually
        tones.spacing = 4
        for tone in ZhuyinEngine.tones {
            tones.addArrangedSubview(key(tone, tint: secondaryBackground) { [weak self] in
                self?.insertZhuyin(tone)
            })
        }
        for mark in ["，","。"] {
            tones.addArrangedSubview(key(mark,tint:secondaryBackground) { [weak self] in self?.insertPunctuation(mark) })
        }
        tones.heightAnchor.constraint(equalToConstant: 36).isActive = true
        root.addArrangedSubview(tones)

        grid.axis = .vertical
        grid.spacing = 5
        grid.distribution = .fillEqually
        root.addArrangedSubview(grid)

        let bottom = UIStackView()
        bottom.axis = .horizontal
        bottom.spacing = 5
        let globe = key("🌐",tint:secondaryBackground) { [weak self] in self?.advanceToNextInputMode() }
        globe.widthAnchor.constraint(equalToConstant: 48).isActive = true
        bottom.addArrangedSubview(globe)

        style(numberButton,tint:secondaryBackground)
        numberButton.widthAnchor.constraint(equalToConstant: 57).isActive = true
        numberButton.addAction(UIAction { [weak self] _ in self?.cycleMode() },for:.touchUpInside)
        bottom.addArrangedSubview(numberButton)

        style(spaceButton,tint:keyBackground)
        spaceButton.addAction(UIAction { [weak self] _ in self?.spacePressed() },for:.touchUpInside)
        bottom.addArrangedSubview(spaceButton)

        let enter = key("換行",tint:.systemBlue,foreground:.white) { [weak self] in
            self?.commitComposition()
            self?.textDocumentProxy.insertText("\n")
        }
        enter.widthAnchor.constraint(equalToConstant: 66).isActive = true
        bottom.addArrangedSubview(enter)
        bottom.heightAnchor.constraint(equalToConstant: 44).isActive = true
        root.addArrangedSubview(bottom)
    }

    private func refresh() {
        let sets: [[String]]
        switch mode {
        case .zhuyin: sets = ZhuyinEngine.groups; numberButton.setTitle("123",for:.normal)
        case .numbers: sets = (1...9).map { [String($0)] }; numberButton.setTitle("#+=",for:.normal)
        case .symbols: sets = ["！","？","、","（","）","：","；","／","＠"].map { [$0] }; numberButton.setTitle("ABC",for:.normal)
        case .english: sets = [["a","b","c"],["d","e","f"],["g","h","i"],["j","k","l"],["m","n","o"],["p","q","r"],["s","t","u"],["v","w","x"],["y","z"]]; numberButton.setTitle("注音",for:.normal)
        }
        spaceButton.setTitle(mode == .numbers ? "0" : "空白",for:.normal)
        for child in grid.arrangedSubviews { grid.removeArrangedSubview(child); child.removeFromSuperview() }
        for rowIndex in 0..<3 {
            let row=UIStackView()
            row.axis = .horizontal
            row.spacing = 5
            row.distribution = .fillEqually
            for columnIndex in 0..<3 {
                let index=rowIndex*3+columnIndex
                let chars=sets[index]
                let split=(chars.count+1)/2
                let title=chars.count > 1 ? chars.prefix(split).joined(separator:" ") + "\n" + chars.dropFirst(split).joined(separator:" ") : chars.joined()
                let button=key(title,tint:keyBackground,size:mode == .zhuyin ? 19 : 22) { [weak self] in
                    self?.tapGrid(index, sets: sets)
                }
                button.titleLabel?.numberOfLines = 2
                button.titleLabel?.textAlignment = .center
                button.accessibilityLabel=chars.joined(separator:"、")
                row.addArrangedSubview(button)
            }
            grid.addArrangedSubview(row)
        }

        for child in candidateStack.arrangedSubviews {candidateStack.removeArrangedSubview(child); child.removeFromSuperview()}
        typedLabel.text=engine.isEmpty ? "" : engine.text
        if let selectedGroup {
            let choices=sets[selectedGroup]
            for option in choices {
                addOption(option,highlight:true) { [weak self] in
                    guard let self else {return}
                    if self.mode == .english {
                        self.commitComposition()
                        self.textDocumentProxy.insertText(option)
                        self.selectedGroup=nil
                        self.refresh()
                    } else { self.insertZhuyin(option) }
                }
            }
            addOption("取消",highlight:false) { [weak self] in self?.selectedGroup=nil; self?.refresh() }
        } else {
            let choices=engine.isEmpty ? ["你好","謝謝","好的","收到","早安"] : lexicon.candidates(for:engine.syllables).map(\.word)
            if choices.isEmpty && !engine.isEmpty {
                addOption("輸出注音",highlight:false) { [weak self] in
                    guard let self else {return}
                    self.textDocumentProxy.insertText(self.engine.commit(self.engine.text))
                    self.refresh()
                }
            }
            for choice in choices.prefix(12) {
                addOption(choice,highlight:false) { [weak self] in
                    guard let self else {return}
                    self.textDocumentProxy.insertText(self.engine.commit(choice))
                    self.refresh()
                }
            }
        }
        addOption("⌫",highlight:false) { [weak self] in self?.backspace() }
    }
    private func tapGrid(_ index: Int,sets: [[String]]) {
        switch mode {
        case .zhuyin, .english: selectedGroup=index; refresh()
        case .numbers:
            commitComposition(); textDocumentProxy.insertText(String(index+1))
        case .symbols:
            commitComposition(); textDocumentProxy.insertText(sets[index][0])
        }
    }
    private func insertZhuyin(_ character: String) {
        engine.append(character)
        selectedGroup=nil
        refresh()
    }
    private func insertPunctuation(_ value: String) {
        commitComposition(); textDocumentProxy.insertText(value); selectedGroup=nil; refresh()
    }
    private func commitComposition() {
        guard !engine.isEmpty else {return}
        let text=lexicon.candidates(for:engine.syllables).first?.word ?? engine.text
        textDocumentProxy.insertText(engine.commit(text))
    }
    private func spacePressed() {
        if mode == .numbers {textDocumentProxy.insertText("0")}
        else if engine.isEmpty {textDocumentProxy.insertText(" ")}
        else {commitComposition()}
        selectedGroup=nil; refresh()
    }
    private func backspace() {
        if selectedGroup != nil {selectedGroup=nil}
        else if !engine.deleteLast() {textDocumentProxy.deleteBackward()}
        refresh()
    }
    private func cycleMode() {
        selectedGroup=nil
        switch mode {
        case .zhuyin:mode = .numbers
        case .numbers:mode = .symbols
        case .symbols:mode = .english
        case .english:mode = .zhuyin
        }
        refresh()
    }
    private func addOption(_ title: String,highlight: Bool,action:@escaping () -> Void) {
        let button=key(title,tint:highlight ? .systemBlue : .tertiarySystemFill,foreground:highlight ? .white : .label,size:17,action:action)
        button.contentEdgeInsets=UIEdgeInsets(top:4,left:10,bottom:4,right:10)
        button.heightAnchor.constraint(equalToConstant:35).isActive=true
        candidateStack.addArrangedSubview(button)
    }
    private func key(_ title:String,tint:UIColor,foreground:UIColor = .label,size:CGFloat = 19,action:@escaping () -> Void) -> UIButton {
        let button=UIButton(type:.system)
        button.setTitle(title,for:.normal)
        style(button,tint:tint,foreground:foreground,size:size)
        button.addAction(UIAction { _ in action() },for:.touchUpInside)
        return button
    }
    private func style(_ button:UIButton,tint:UIColor,foreground:UIColor = .label,size:CGFloat = 19) {
        button.backgroundColor=tint
        button.setTitleColor(foreground,for:.normal)
        button.titleLabel?.font = .systemFont(ofSize:size)
        button.layer.cornerRadius=8
        button.layer.shadowColor=UIColor.black.cgColor
        button.layer.shadowOpacity=0.1
        button.layer.shadowOffset=CGSize(width:0,height:1)
    }
}
