import Foundation

struct LexiconCandidate {
    let word: String
    let score: Int
}
final class PhoneticLexicon {
    private struct Entry { let word: String; let reading: String; let score: Int }
    private var index: [String: [Entry]] = [:]
    static func untoned(_ text: String) -> String { text.filter { !"˙ˊˇˋˉ ".contains($0) } }
    convenience init(bundle: Bundle) {
        let data = bundle.url(forResource: "lexicon", withExtension: "tsv")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        self.init(text: data)
    }
    init(text: String) {
        for line in text.split(whereSeparator: \.isNewline) {
            if line.first == "#" { continue }
            let cols = line.split(separator: "\t")
            guard cols.count >= 2 else { continue }
            let word=String(cols[0]), reading=String(cols[1])
            let score=cols.count > 2 ? (Int(cols[2]) ?? 0) : 0
            index[Self.untoned(reading),default:[]].append(Entry(word: word, reading: reading, score: score))
        }
        for (k,v) in index { index[k] = v.sorted { $0.score > $1.score } }
    }
    func candidates(for syllables: [String]) -> [LexiconCandidate] {
        guard !syllables.isEmpty else {return []}
        let raw=syllables.joined(separator:" "), items=index[Self.untoned(raw)] ?? []
        let ranked=items.map { entry -> LexiconCandidate in
            let exact=entry.reading == raw ? 100000 : 0
            return LexiconCandidate(word: entry.word,score: entry.score + exact)
        }.sorted { $0.score > $1.score }
        var seen=Set<String>(); let unique=ranked.filter { seen.insert($0.word).inserted }
        if !unique.isEmpty { return Array(unique.prefix(14)) }
        if syllables.count > 1 {
            let words=syllables.compactMap { candidates(for:[$0]).first?.word }
            if words.count == syllables.count {return [LexiconCandidate(word:words.joined(),score:1)]}
        }
        return []
    }
}
