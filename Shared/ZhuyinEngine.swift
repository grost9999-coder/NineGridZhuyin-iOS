import Foundation

/// Pure local input engine. Never sends typed text to a server.
struct ZhuyinEngine {
    static let groups: [[String]] = [
        ["ㄅ","ㄆ","ㄇ","ㄈ"], ["ㄉ","ㄊ","ㄋ","ㄌ"], ["ㄍ","ㄎ","ㄏ","ㄐ"],
        ["ㄑ","ㄒ","ㄓ","ㄔ"], ["ㄕ","ㄖ","ㄗ","ㄘ","ㄙ"], ["ㄧ","ㄨ","ㄩ"],
        ["ㄚ","ㄛ","ㄜ","ㄝ"], ["ㄞ","ㄟ","ㄠ","ㄡ"], ["ㄢ","ㄣ","ㄤ","ㄥ","ㄦ"]
    ]
    static let tones = ["˙","ˊ","ˇ","ˋ"]
    private static let initials = Set("ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙ".map(String.init))
    private static let vowels = Set("ㄧㄨㄩㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦ".map(String.init))
    private var complete: [String] = []
    private var active: [String] = []
    var syllables: [String] { complete + (active.isEmpty ? [] : [active.joined()]) }
    var text: String { syllables.joined(separator: " ") }
    var isEmpty: Bool { complete.isEmpty && active.isEmpty }
    mutating func append(_ symbol: String) {
        guard Self.groups.flatMap({$0}).contains(symbol) || Self.tones.contains(symbol) else { return }
        if Self.tones.contains(symbol) {
            guard !active.isEmpty else { return }
            active.removeAll(where: { Self.tones.contains($0) })
            active.append(symbol)
            return
        }
        let consonant = Self.initials.contains(symbol)
        let vowelSeen = active.contains(where: { Self.vowels.contains($0) })
        let toneSeen = active.contains(where: { Self.tones.contains($0) })
        if !active.isEmpty && (toneSeen || (consonant && vowelSeen) || (consonant && active.contains(where: {Self.initials.contains($0)}))) {
            complete.append(active.joined()); active = []
        }
        active.append(symbol)
    }
    @discardableResult mutating func deleteLast() -> Bool {
        if !active.isEmpty { active.removeLast(); return true }
        guard let prior = complete.popLast() else { return false }
        active = prior.map(String.init)
        if !active.isEmpty { active.removeLast() }
        return true
    }
    mutating func commit(_ text: String) -> String { clear(); return text }
    mutating func clear() { complete = []; active = [] }
}
