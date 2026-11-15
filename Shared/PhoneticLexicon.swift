import Foundation

enum ZhuyinKey: Equatable {
    case group(Int)
    case symbol(String)

    var groupIndex: Int? {
        switch self {
        case .group(let index): return index
        case .symbol(let value): return ZhuyinEngine.groups.firstIndex { $0.contains(value) }
        }
    }
    func accepts(_ symbol: String) -> Bool {
        switch self {
        case .group(let index): return ZhuyinEngine.groups[index].contains(symbol)
        case .symbol(let value): return value == symbol
        }
    }
}

struct SmartZhuyinInput {
    private(set) var keys: [ZhuyinKey] = []
    var isEmpty: Bool { keys.isEmpty }
    /// The 3x3 grid doubles as a number pad: grid key n is digit n, so a run of
    /// plain group presses can also be committed as digits. Nil once a tone or a
    /// specified symbol is involved.
    var digitText: String? {
        guard !keys.isEmpty else { return nil }
        var digits = ""
        for key in keys {
            guard case .group(let index) = key else { return nil }
            digits += String(index + 1)
        }
        return digits
    }
    var display: String {
        keys.map {
            switch $0 {
            case .group(let index): return String(index + 1)
            case .symbol(let symbol): return symbol
            }
        }.joined()
    }
    mutating func append(_ key: ZhuyinKey) {
        guard keys.count < 48 else { return }
        if case .symbol(let symbol) = key, ZhuyinEngine.tones.contains(symbol) {
            guard !keys.isEmpty else { return }
            if case .symbol(let previous) = keys.last!, ZhuyinEngine.tones.contains(previous) {
                keys.removeLast()
            }
        }
        keys.append(key)
    }
    @discardableResult mutating func deleteLast() -> Bool {
        guard !keys.isEmpty else { return false }
        keys.removeLast()
        return true
    }
    mutating func clear() { keys.removeAll() }
}

struct LexiconCandidate {
    let word: String
    let reading: String
    let score: Int
    var completesInput = false
    var corrected = false
    /// True for the digit-string candidate offered next to real words.
    var literal = false
}

/// Group signatures keep the expanded lexicon compact enough for a keyboard extension.
final class PhoneticLexicon {
    private struct Entry {
        let word: String
        let reading: String
        let score: Int
        let signature: String
    }
    private struct Learned: Codable {
        let word: String
        let reading: String
        var count: Int
        var contexts: [String: Int]
        var lastUsed: TimeInterval
    }
    private struct Path {
        let word: String
        let reading: String
        let score: Int
        let completesInput: Bool
    }
    private var entries: [Entry] = []
    private var index: [String: [Int]] = [:]
    private var prefixes: [String: [Int]] = [:]
    private var continuations: [String: [Int]] = [:]
    private var learned: [String: Learned] = [:]
    private let defaults: UserDefaults?
    private let learningKey = "smart-zhuyin-learning-v1"

    static func untoned(_ text: String) -> String { text.filter { !"˙ˊˇˋˉ ".contains($0) } }

    convenience init(bundle: Bundle) {
        let data = bundle.url(forResource: "lexicon", withExtension: "tsv")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        self.init(text: data, defaults: .standard)
    }
    init(text: String, defaults: UserDefaults? = nil) {
        self.defaults = defaults
        if let data = defaults?.data(forKey: learningKey),
           let saved = try? JSONDecoder().decode([String: Learned].self, from: data) {
            learned = saved
        }
        for line in text.split(whereSeparator: \.isNewline) {
            if line.first == "#" { continue }
            let columns = line.split(separator: "\t")
            guard columns.count >= 2 else { continue }
            let word = String(columns[0]), reading = String(columns[1])
            let signature = Self.signature(reading)
            guard !signature.isEmpty, signature.count <= 40 else { continue }
            let entry = Entry(word: word, reading: reading, score: columns.count > 2 ? Int(columns[2]) ?? 0 : 0, signature: signature)
            let id = entries.count
            entries.append(entry)
            index[signature, default: []].append(id)
        }
        // Learned phrases remain available even when a later dictionary update omits them.
        for item in learned.values {
            let signature = Self.signature(item.reading)
            guard !signature.isEmpty else { continue }
            let id = entries.count
            entries.append(Entry(word: item.word, reading: item.reading, score: 1300, signature: signature))
            index[signature, default: []].append(id)
        }
        let ranked = entries.indices.sorted {
            if entries[$0].score != entries[$1].score { return entries[$0].score > entries[$1].score }
            return entries[$0].word < entries[$1].word
        }
        for id in ranked {
            let entry = entries[id]
            let signature = entry.signature
            for length in 1..<min(signature.count, 7) {
                let key = String(signature.prefix(length))
                if prefixes[key, default: []].count < 8 { prefixes[key, default: []].append(id) }
            }
            guard entry.word.count > 1, entry.word.count <= 6 else { continue }
            for length in 1..<min(entry.word.count, 3) {
                let key = String(entry.word.prefix(length))
                if continuations[key, default: []].count < 10 { continuations[key, default: []].append(id) }
            }
        }
    }

    private static func signature(_ reading: String) -> String {
        untoned(reading).compactMap { symbol in
            ZhuyinEngine.groups.firstIndex { $0.contains(String(symbol)) }.map { String($0 + 1) }
        }.joined()
    }
    private static func symbols(_ reading: String) -> [String] {
        reading.split(separator: " ").flatMap { syllable -> [String] in
            var symbols = syllable.map(String.init)
            // First tone is implicit in dictionary files, explicit while matching.
            if !symbols.contains(where: { ZhuyinEngine.tones.contains($0) }) { symbols.append("ˉ") }
            return symbols
        }
    }
    private func matches(_ entry: Entry, keys: ArraySlice<ZhuyinKey>, completion: Bool) -> Bool {
        let symbols = Self.symbols(entry.reading)
        var position = 0
        for key in keys {
            while position < symbols.count, ZhuyinEngine.tones.contains(symbols[position]), !key.accepts(symbols[position]) {
                position += 1
            }
            guard position < symbols.count, key.accepts(symbols[position]) else { return false }
            position += 1
        }
        while position < symbols.count, ZhuyinEngine.tones.contains(symbols[position]) { position += 1 }
        return completion || position == symbols.count
    }
    private func contextKey(_ context: String) -> String {
        String(context.suffix(8))
    }
    private func bonus(word: String, reading: String, context: String) -> Int {
        guard let item = learned[reading + "|" + word] else { return 0 }
        return min(item.count, 30) * 160 + min(item.contexts[contextKey(context)] ?? 0, 12) * 300
    }
    private func prune(_ paths: [Path], limit: Int) -> [Path] {
        var seen = Set<String>()
        return Array(paths.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.word < $1.word
        }.filter { seen.insert($0.word).inserted }.prefix(limit))
    }
    func candidates(for syllables: [String]) -> [LexiconCandidate] {
        candidates(for: syllables.flatMap { $0.map { ZhuyinKey.symbol(String($0)) } })
    }
    func candidates(for keys: [ZhuyinKey], context: String = "", allowCorrections: Bool = true) -> [LexiconCandidate] {
        guard !keys.isEmpty else { return [] }
        var chart = Array(repeating: [Path](), count: keys.count + 1)
        chart[0] = [Path(word: "", reading: "", score: 0, completesInput: false)]
        for start in keys.indices where !chart[start].isEmpty {
            chart[start] = prune(chart[start], limit: 5)
            var signature = ""
            for end in (start + 1)...min(keys.count, start + 40) {
                if let group = keys[end - 1].groupIndex { signature += String(group + 1) }
                guard !signature.isEmpty else { continue }
                var ids = index[signature] ?? []
                let atEnd = end == keys.count
                if atEnd { ids += prefixes[signature] ?? [] }
                var seen = Set<Int>()
                var matchesAtEnd: [(Entry, Bool)] = []
                for id in ids where seen.insert(id).inserted {
                    let entry = entries[id]
                    let complete = entry.signature.count > signature.count
                    if matches(entry, keys: keys[start..<end], completion: atEnd && complete) {
                        matchesAtEnd.append((entry, complete))
                    }
                }
                // Bound the beam while retaining a broad candidate list at the final position.
                matchesAtEnd.sort { $0.0.score > $1.0.score }
                for path in chart[start] {
                    for (entry, complete) in matchesAtEnd.prefix(atEnd ? 80 : 8) {
                        let reading = path.reading.isEmpty ? entry.reading : path.reading + " " + entry.reading
                        let word = path.word + entry.word
                        let score = path.score + entry.score - 1800
                            + bonus(word: entry.word, reading: entry.reading, context: context + path.word)
                            + (path.word.isEmpty ? 0 : bonus(word: word, reading: reading, context: context))
                            - (complete ? 1800 : 0)
                        chart[end].append(Path(word: word, reading: reading, score: score, completesInput: complete))
                    }
                }
                if chart[end].count > 200 { chart[end] = prune(chart[end], limit: atEnd ? 60 : 5) }
            }
        }
        let results = prune(chart[keys.count], limit: 60).map {
            LexiconCandidate(word: $0.word, reading: $0.reading, score: $0.score, completesInput: $0.completesInput)
        }
        guard results.isEmpty, allowCorrections, keys.count >= 3, keys.count <= 12 else { return results }
        // Only offer adjacent-key corrections when the exact input has no candidate.
        var corrections: [LexiconCandidate] = []
        for position in keys.indices {
            guard case .group(let group) = keys[position] else { continue }
            for adjacent in 0..<9 where abs(adjacent / 3 - group / 3) + abs(adjacent % 3 - group % 3) == 1 {
                var changed = keys
                changed[position] = .group(adjacent)
                corrections += candidates(for: changed, context: context, allowCorrections: false).prefix(3).map {
                    LexiconCandidate(word: $0.word, reading: $0.reading, score: $0.score - 2000,
                                     completesInput: $0.completesInput, corrected: true)
                }
            }
        }
        var seen = Set<String>()
        return Array(corrections.sorted { $0.score > $1.score }.filter { seen.insert($0.word).inserted }.prefix(20))
    }

    func recordSelection(_ candidate: LexiconCandidate, context: String) {
        guard !candidate.reading.isEmpty else { return }
        let key = candidate.reading + "|" + candidate.word
        var item = learned[key] ?? Learned(word: candidate.word, reading: candidate.reading, count: 0, contexts: [:], lastUsed: 0)
        item.count += 1
        let prior = contextKey(context)
        item.contexts[prior, default: 0] += 1
        item.contexts = Dictionary(uniqueKeysWithValues: item.contexts.sorted { $0.value > $1.value }.prefix(12).map { ($0.key, $0.value) })
        item.lastUsed = Date().timeIntervalSince1970
        learned[key] = item
        if learned.count > 500 {
            learned = Dictionary(uniqueKeysWithValues: learned.sorted { $0.value.lastUsed > $1.value.lastUsed }.prefix(500).map { ($0.key, $0.value) })
        }
        if let data = try? JSONEncoder().encode(learned) { defaults?.set(data, forKey: learningKey) }
    }

    func suggestions(after context: String) -> [LexiconCandidate] {
        guard !context.isEmpty else {
            return ["你好", "謝謝", "好的", "收到", "早安"].map { LexiconCandidate(word: $0, reading: "", score: 0) }
        }
        var results: [LexiconCandidate] = []
        for length in 1...min(context.count, 6) {
            let prefix = String(context.suffix(length))
            for id in continuations[prefix] ?? [] {
                let entry = entries[id]
                let word = String(entry.word.dropFirst(length))
                guard !word.isEmpty else { continue }
                results.append(LexiconCandidate(word: word, reading: "", score: entry.score + length * 100))
            }
        }
        for item in learned.values {
            let count = item.contexts[contextKey(context)] ?? 0
            if count > 0 { results.append(LexiconCandidate(word: item.word, reading: item.reading, score: count * 500 + item.count * 50)) }
        }
        var seen = Set<String>()
        return Array(results.sorted { $0.score > $1.score }.filter { seen.insert($0.word).inserted }.prefix(20))
    }

    func clearLearning() {
        learned.removeAll()
        defaults?.removeObject(forKey: learningKey)
    }
}

