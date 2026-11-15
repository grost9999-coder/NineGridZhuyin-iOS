import UIKit

final class KeyboardViewController: UIInputViewController {
    private enum Mode { case zhuyin, english, numbers, symbols, emoji }
    private struct Commit {
        let text: String
        let keys: [ZhuyinKey]
    }
    private var mode: Mode = .zhuyin
    private var previousLanguage: Mode = .zhuyin
    private var input = SmartZhuyinInput()
    private lazy var lexicon = PhoneticLexicon(bundle: .main)
    private var candidates: [LexiconCandidate] = []
    private var selectedGroup: Int?
    private var expanded = false
    private var uppercase = false
    private var emojiCategory = 0
    private var emojiPage = 0
    private var lastCommit: Commit?
    private var deleteTimer: Timer?
    private let typedLabel = UILabel()
    private let candidateScroll = UIScrollView()
    private let candidateStack = UIStackView()
    private let expandedScroll = UIScrollView()
    private let expandedStack = UIStackView()
    private let grid = UIStackView()
    private let tools = UIStackView()
    private let languageButton = UIButton(type: .system)
    private let numberButton = UIButton(type: .system)
    private let emojiButton = UIButton(type: .system)
    private let spaceButton = UIButton(type: .system)
    private let expandButton = UIButton(type: .system)
    private let undoButton = UIButton(type: .system)
    private let background = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.14, alpha: 1) : UIColor(white: 0.84, alpha: 1) }
    private let keyBackground = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.28, alpha: 1) : .white }
    private let secondaryBackground = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.36, alpha: 1) : UIColor(white: 0.71, alpha: 1) }
    private let emojiCategories = ["常用", "笑臉", "手勢", "食物", "愛心", "生活"]
    private let emojiPages = [
        ["😊","😂","🤣","🥰","😍","😘","😎","🥹","😭","😅","😆","🙂","🙃","😉","🤔","😴","😤","😱","😢","🥺","🤗","🤭","😋","😇","🙄","😳","😮","🤩","😔","🥲"],
        ["😊","😂","🤣","🥰","😍","😘","😎","🥹","😭","😅","😆","🙂","🙃","😉","🤔","😴","😤","😱","😢","🥺","🤗","🤭","😋","😇","🙄","😳","😮","🤩","😔","🥲"],
        ["👍","👎","👏","🙌","🙏","👌","✌️","🤞","🤟","🤘","🤙","👋","🫶","💪","👊","✊","🤝","🫰","☝️","👈","👉","👆","👇","🙋","🙆","🙅","🤷","💅","🖐️","✋"],
        ["🍗","🍟","🍔","🍕","🍱","🍜","🍚","🍙","🥟","🍤","🥗","🍰","🍩","🍪","🍫","🍦","🍋","🍊","🍎","🍓","🍉","🥭","🍍","🥑","☕️","🍵","🧋","🥤","🍺","🥂"],
        ["❤️","🧡","💛","💚","💙","💜","🖤","🤍","🤎","🩷","💖","💗","💓","💞","💕","💘","💝","💟","❣️","💔","❤️‍🔥","❤️‍🩹","💯","✨","⭐️","🌟","🔥","🎉","🎊","💐"],
        ["☀️","🌧️","🌈","🌙","🏠","🏪","🚗","🚚","🛵","🚆","✈️","📍","📅","⏰","📞","📱","💰","💵","🛒","🎁","🎈","🎂","💊","🏥","👨‍👩‍👧","🐶","🐱","🌸","🍀","🧧"]
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = background
        build()
        renderKeys()
        refreshCandidates()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        deleteTimer?.invalidate()
        deleteTimer = nil
    }
    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        if let commit = lastCommit, !(textDocumentProxy.documentContextBeforeInput ?? "").hasSuffix(commit.text) {
            lastCommit = nil
        }
        if isViewLoaded { refreshCandidates() }
    }
    private func build() {
        let height = view.heightAnchor.constraint(equalToConstant: 330)
        height.priority = .defaultHigh
        height.isActive = true
        let root = UIStackView()
        root.axis = .vertical
        root.spacing = 5
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -5),
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 5),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -5)
        ])
        let composition = UIStackView()
        composition.spacing = 4
        typedLabel.font = .systemFont(ofSize: 14)
        typedLabel.textColor = .secondaryLabel
        typedLabel.lineBreakMode = .byTruncatingHead
        typedLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        composition.addArrangedSubview(typedLabel)
        style(undoButton, tint: .clear, size: 21)
        undoButton.setTitle("↶", for: .normal)
        undoButton.accessibilityLabel = "撤回上一筆選字，重新選擇"
        undoButton.widthAnchor.constraint(equalToConstant: 34).isActive = true
        undoButton.addAction(UIAction { [weak self] _ in self?.undoSelection() }, for: .touchUpInside)
        composition.addArrangedSubview(undoButton)
        composition.heightAnchor.constraint(equalToConstant: 24).isActive = true
        root.addArrangedSubview(composition)

        let bar = UIStackView()
        bar.spacing = 4
        candidateScroll.showsHorizontalScrollIndicator = false
        candidateStack.axis = .horizontal
        candidateStack.spacing = 5
        install(candidateStack, in: candidateScroll, horizontal: true)
        bar.addArrangedSubview(candidateScroll)
        style(expandButton, tint: secondaryBackground, size: 20)
        expandButton.widthAnchor.constraint(equalToConstant: 36).isActive = true
        expandButton.accessibilityLabel = "展開或收合候選字"
        expandButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.expanded.toggle()
            self.refreshCandidates()
        }, for: .touchUpInside)
        bar.addArrangedSubview(expandButton)
        bar.heightAnchor.constraint(equalToConstant: 44).isActive = true
        root.addArrangedSubview(bar)

        tools.axis = .horizontal
        tools.spacing = 4
        tools.distribution = .fillEqually
        tools.heightAnchor.constraint(equalToConstant: 34).isActive = true
        root.addArrangedSubview(tools)
        grid.axis = .vertical
        grid.spacing = 5
        grid.distribution = .fillEqually
        root.addArrangedSubview(grid)
        expandedStack.axis = .vertical
        expandedStack.spacing = 5
        install(expandedStack, in: expandedScroll, horizontal: false)
        root.addArrangedSubview(expandedScroll)
        expandedScroll.isHidden = true

        let bottom = UIStackView()
        bottom.spacing = 4
        let globe = key("🌐", tint: secondaryBackground) { [weak self] in self?.advanceToNextInputMode() }
        globe.widthAnchor.constraint(equalToConstant: 34).isActive = true
        globe.accessibilityLabel = "切換系統鍵盤"
        bottom.addArrangedSubview(globe)
        configure(languageButton, title: "中/英", width: 45, label: "切換中文或英文") { [weak self] in
            guard let self else { return }
            self.switchMode(self.previousLanguage == .english ? .zhuyin : .english)
        }
        bottom.addArrangedSubview(languageButton)
        configure(numberButton, title: "123", width: 43, label: "切換數字與符號") { [weak self] in
            guard let self else { return }
            self.switchMode(self.mode == .numbers ? .symbols : .numbers)
        }
        bottom.addArrangedSubview(numberButton)
        configure(emojiButton, title: "😊", width: 38, label: "切換表情符號") { [weak self] in
            guard let self else { return }
            self.switchMode(self.mode == .emoji ? self.previousLanguage : .emoji)
        }
        bottom.addArrangedSubview(emojiButton)
        style(spaceButton, tint: keyBackground)
        spaceButton.addAction(UIAction { [weak self] _ in self?.spacePressed() }, for: .touchUpInside)
        spaceButton.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(moveCursor(_:))))
        bottom.addArrangedSubview(spaceButton)
        let enter = key("換行", tint: .systemBlue, foreground: .white, size: 18) { [weak self] in
            guard let self else { return }
            if self.commitComposition() { self.textDocumentProxy.insertText("\n"); self.lastCommit = nil }
            self.refreshCandidates()
        }
        enter.widthAnchor.constraint(equalToConstant: 54).isActive = true
        bottom.addArrangedSubview(enter)
        bottom.heightAnchor.constraint(equalToConstant: 44).isActive = true
        root.addArrangedSubview(bottom)
    }
    private func configure(_ button: UIButton, title: String, width: CGFloat, label: String, action: @escaping () -> Void) {
        style(button, tint: secondaryBackground, size: 16)
        button.setTitle(title, for: .normal)
        button.accessibilityLabel = label
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    }
    private func install(_ stack: UIStackView, in scroll: UIScrollView, horizontal: Bool) {
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            horizontal ? stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
                : stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])
    }
    private func clear(_ stack: UIStackView) {
        for child in stack.arrangedSubviews { stack.removeArrangedSubview(child); child.removeFromSuperview() }
    }
    private func renderKeys() {
        clear(grid)
        clear(tools)
        switch mode {
        case .zhuyin:
            for tone in ZhuyinEngine.tones {
                tools.addArrangedSubview(key(tone, tint: secondaryBackground) { [weak self] in self?.append(.symbol(tone)) })
            }
            for mark in ["，", "。"] { addTool(mark) }
            tools.addArrangedSubview(deleteKey())
            for rowIndex in 0..<3 {
                let row = makeRow()
                for index in (rowIndex * 3)..<(rowIndex * 3 + 3) {
                    let symbols = ZhuyinEngine.groups[index]
                    let split = (symbols.count + 1) / 2
                    let title = symbols.prefix(split).joined(separator: " ") + "\n" + symbols.dropFirst(split).joined(separator: " ")
                    let button = key(title, tint: keyBackground, size: 21) { [weak self] in self?.append(.group(index)) }
                    button.titleLabel?.numberOfLines = 2
                    button.titleLabel?.textAlignment = .center
                    button.accessibilityLabel = symbols.joined(separator: "、")
                    button.accessibilityHint = "點一下智慧辨識，長按可指定注音"
                    button.tag = index
                    button.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(specifySymbol(_:))))
                    row.addArrangedSubview(button)
                }
                grid.addArrangedSubview(row)
            }
        case .english:
            for value in ["'", "\"", "@", "-", ".", ","] { addTool(value) }
            tools.addArrangedSubview(deleteKey())
            for letters in ["qwertyuiop", "asdfghjkl", "zxcvbnm"] {
                let row = makeRow()
                if letters == "zxcvbnm" {
                    row.addArrangedSubview(key(uppercase ? "⇧●" : "⇧", tint: secondaryBackground, size: 17) { [weak self] in
                        guard let self else { return }
                        self.uppercase.toggle()
                        self.renderKeys()
                    })
                }
                for character in letters {
                    let letter = uppercase ? String(character).uppercased() : String(character)
                    row.addArrangedSubview(key(letter, tint: keyBackground, size: 19) { [weak self] in self?.insertLiteral(letter) })
                }
                if letters == "zxcvbnm" { row.addArrangedSubview(deleteKey()) }
                grid.addArrangedSubview(row)
            }
        case .numbers, .symbols:
            for value in mode == .numbers ? [".", ",", "-", "+", "/", ":", "%"] : ["，", "。", "！", "？", "、", "：", "；"] { addTool(value) }
            tools.addArrangedSubview(deleteKey())
            let pages = mode == .numbers
                ? [["1","2","3"],["4","5","6"],["7","8","9"]]
                : [["!","?","@"],["(",")","#"],["$","&","="]]
            for values in pages {
                let row = makeRow()
                for value in values { row.addArrangedSubview(key(value, tint: keyBackground, size: 25) { [weak self] in self?.insertLiteral(value) }) }
                grid.addArrangedSubview(row)
            }
        case .emoji:
            for (index, name) in emojiCategories.enumerated() {
                tools.addArrangedSubview(key(name, tint: index == emojiCategory ? .systemBlue : secondaryBackground,
                                             foreground: index == emojiCategory ? .white : .label, size: 13) { [weak self] in
                    guard let self else { return }
                    self.emojiCategory = index
                    self.emojiPage = 0
                    self.renderKeys()
                    self.refreshCandidates()
                })
            }
            tools.addArrangedSubview(deleteKey())
            let recent = UserDefaults.standard.stringArray(forKey: "recent-emoji") ?? []
            let all = emojiCategory == 0 && !recent.isEmpty ? recent : emojiPages[emojiCategory]
            emojiPage = min(emojiPage, (all.count - 1) / 18)
            let values = Array(all[(emojiPage * 18)..<min(emojiPage * 18 + 18, all.count)])
            for start in stride(from: 0, to: values.count, by: 6) {
                let row = makeRow()
                for value in values[start..<min(start + 6, values.count)] {
                    row.addArrangedSubview(key(value, tint: keyBackground, size: 25) { [weak self] in
                        guard let self else { return }
                        self.insertLiteral(value)
                        var recent = UserDefaults.standard.stringArray(forKey: "recent-emoji") ?? []
                        recent.removeAll { $0 == value }
                        recent.insert(value, at: 0)
                        UserDefaults.standard.set(Array(recent.prefix(30)), forKey: "recent-emoji")
                    })
                }
                grid.addArrangedSubview(row)
            }
        }
        languageButton.setTitle(mode == .zhuyin ? "英" : "中文", for: .normal)
        numberButton.setTitle(mode == .numbers ? "#+=" : "123", for: .normal)
        spaceButton.setTitle(mode == .numbers ? "0" : input.isEmpty ? "空白" : "選字", for: .normal)
        spaceButton.accessibilityHint = "左右滑動可移動文字游標"
    }
    private func makeRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 4
        row.distribution = .fillEqually
        return row
    }
    private func addTool(_ value: String) {
        tools.addArrangedSubview(key(value, tint: secondaryBackground, size: 18) { [weak self] in self?.insertLiteral(value) })
    }
    private var context: String { textDocumentProxy.documentContextBeforeInput ?? "" }

    private func refreshCandidates() {
        clear(candidateStack)
        clear(expandedStack)
        if let group = selectedGroup {
            typedLabel.text = "指定注音 · 點選後繼續輸入"
            for symbol in ZhuyinEngine.groups[group] {
                candidateStack.addArrangedSubview(candidateButton(symbol, first: false) { [weak self] in self?.append(.symbol(symbol)) })
            }
            candidateStack.addArrangedSubview(candidateButton("取消", first: false) { [weak self] in
                self?.selectedGroup = nil
                self?.refreshCandidates()
            })
        } else if mode == .emoji {
            candidates = []
            typedLabel.text = "表情符號 · " + emojiCategories[emojiCategory]
            let recent = UserDefaults.standard.stringArray(forKey: "recent-emoji") ?? []
            let count = emojiCategory == 0 && !recent.isEmpty ? recent.count : emojiPages[emojiCategory].count
            let pages = (count + 17) / 18
            for (title, offset) in [("◀︎", -1), ("\(emojiPage + 1) / \(pages)", 0), ("▶︎", 1)] {
                let button = candidateButton(title, first: false) { [weak self] in
                    guard let self else { return }
                    self.emojiPage = (self.emojiPage + offset + pages) % pages
                    self.renderKeys()
                    self.refreshCandidates()
                }
                button.isEnabled = offset != 0 && pages > 1
                candidateStack.addArrangedSubview(button)
            }
        } else {
            candidates = input.isEmpty ? (mode == .zhuyin ? lexicon.suggestions(after: context) : []) : lexicon.candidates(for: input.keys, context: context)
            typedLabel.text = input.isEmpty
                ? (mode == .zhuyin ? "直接連打 · 長按指定注音" : mode == .english ? "英文 QWERTY" : mode == .emoji ? "表情符號 · " + emojiCategories[emojiCategory] : "數字與符號")
                : candidates.first?.reading ?? "尚無符合字詞 · 長按大鍵指定注音"
            for (index, candidate) in candidates.enumerated() {
                let title = candidate.word + (candidate.corrected ? " ≈" : candidate.completesInput ? "…" : "")
                candidateStack.addArrangedSubview(candidateButton(title, first: index == 0 && !input.isEmpty) { [weak self] in self?.choose(candidate) })
            }
            if !input.isEmpty && candidates.isEmpty {
                candidateStack.addArrangedSubview(candidateButton("清除重打", first: false) { [weak self] in self?.input.clear(); self?.refreshCandidates() })
            }
            for start in stride(from: 0, to: candidates.count, by: 3) {
                let row = makeRow()
                for candidate in candidates[start..<min(start + 3, candidates.count)] {
                    let title = candidate.word + (candidate.corrected ? "\n鄰鍵修正" : candidate.completesInput ? "\n補全" : "")
                    let button = candidateButton(title, first: false) { [weak self] in self?.choose(candidate) }
                    button.titleLabel?.numberOfLines = 0
                    button.titleLabel?.lineBreakMode = .byWordWrapping
                    button.titleLabel?.textAlignment = .center
                    button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
                    row.addArrangedSubview(button)
                }
                expandedStack.addArrangedSubview(row)
            }
        }
        candidateScroll.setContentOffset(.zero, animated: false)
        expandedScroll.setContentOffset(.zero, animated: false)
        let showExpanded = expanded && selectedGroup == nil && !candidates.isEmpty
        grid.isHidden = showExpanded
        expandedScroll.isHidden = !showExpanded
        expandButton.setTitle(showExpanded ? "⌃" : "⌄", for: .normal)
        expandButton.isEnabled = selectedGroup == nil && !candidates.isEmpty
        undoButton.isEnabled = lastCommit != nil && input.isEmpty
        undoButton.alpha = undoButton.isEnabled ? 1 : 0.25
        spaceButton.setTitle(mode == .numbers ? "0" : input.isEmpty ? "空白" : "選字", for: .normal)
    }
    private func append(_ key: ZhuyinKey) {
        selectedGroup = nil
        expanded = false
        lastCommit = nil
        input.append(key)
        refreshCandidates()
    }
    @objc private func specifySymbol(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let button = gesture.view as? UIButton else { return }
        selectedGroup = button.tag
        expanded = false
        refreshCandidates()
    }
    private func choose(_ candidate: LexiconCandidate) {
        let keys = input.keys
        lexicon.recordSelection(candidate, context: context)
        textDocumentProxy.insertText(candidate.word)
        input.clear()
        lastCommit = keys.isEmpty ? nil : Commit(text: candidate.word, keys: keys)
        selectedGroup = nil
        expanded = false
        refreshCandidates()
    }
    @discardableResult private func commitComposition() -> Bool {
        guard !input.isEmpty else { return true }
        guard let candidate = candidates.first else {
            typedLabel.text = "請先選擇字詞，或刪除後重打"
            return false
        }
        choose(candidate)
        return true
    }
    private func insertLiteral(_ text: String) {
        guard commitComposition() else { return }
        textDocumentProxy.insertText(text)
        lastCommit = nil
        refreshCandidates()
    }
    private func spacePressed() {
        if mode == .numbers { insertLiteral("0") }
        else if input.isEmpty { insertLiteral(" ") }
        else { _ = commitComposition() }
    }
    private func switchMode(_ newMode: Mode) {
        guard commitComposition() else { return }
        mode = newMode
        if newMode == .zhuyin || newMode == .english { previousLanguage = newMode }
        selectedGroup = nil
        expanded = false
        renderKeys()
        refreshCandidates()
    }
    private func undoSelection() {
        guard input.isEmpty, let commit = lastCommit, context.hasSuffix(commit.text) else { return }
        for _ in commit.text { textDocumentProxy.deleteBackward() }
        for key in commit.keys { input.append(key) }
        lastCommit = nil
        mode = .zhuyin
        previousLanguage = .zhuyin
        renderKeys()
        refreshCandidates()
    }
    private func backspace() {
        if selectedGroup != nil { selectedGroup = nil }
        else if !input.deleteLast() { textDocumentProxy.deleteBackward(); lastCommit = nil }
        refreshCandidates()
    }
    private func deleteKey() -> UIButton {
        let button = key("⌫", tint: secondaryBackground, size: 20) { [weak self] in self?.backspace() }
        button.accessibilityLabel = "刪除，長按連續刪除"
        button.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(repeatDelete(_:))))
        return button
    }
    @objc private func repeatDelete(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            deleteTimer?.invalidate()
            backspace()
            deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { [weak self] _ in self?.backspace() }
        } else if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
            deleteTimer?.invalidate()
            deleteTimer = nil
        }
    }
    @objc private func moveCursor(_ gesture: UIPanGestureRecognizer) {
        guard input.isEmpty else { return }
        let distance = gesture.translation(in: spaceButton).x
        let offset = Int(distance / 10)
        if offset != 0 {
            textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
            gesture.setTranslation(.zero, in: spaceButton)
            lastCommit = nil
        }
    }
    private func candidateButton(_ title: String, first: Bool, action: @escaping () -> Void) -> UIButton {
        let button = key(title, tint: first ? .systemBlue : keyBackground, foreground: first ? .white : .label, size: 20, action: action)
        button.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        button.titleLabel?.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }
    private func key(_ title: String, tint: UIColor, foreground: UIColor = .label, size: CGFloat = 19, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        style(button, tint: tint, foreground: foreground, size: size)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }
    private func style(_ button: UIButton, tint: UIColor, foreground: UIColor = .label, size: CGFloat = 19) {
        button.backgroundColor = tint
        button.setTitleColor(foreground, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: size)
        button.layer.cornerRadius = 7
    }
}

