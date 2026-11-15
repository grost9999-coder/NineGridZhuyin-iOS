import Foundation
import Darwin
@main struct EngineTests {
    static func main() {
        let symbols = ZhuyinEngine.groups.flatMap{$0}
        assert(symbols.count == 37 && Set(symbols).count == 37)
        let dict=PhoneticLexicon(text:"你\tㄋㄧˇ\t950\n好\tㄏㄠˇ\t950\n你好\tㄋㄧˇ ㄏㄠˇ\t2000")
        var engine=ZhuyinEngine()
        for c in ["ㄋ","ㄧ","ˇ","ㄏ","ㄠ","ˇ"] {engine.append(c)}
        assert(engine.syllables == ["ㄋㄧˇ","ㄏㄠˇ"])
        assert(dict.candidates(for:engine.syllables).first?.word=="你好")
        assert(engine.commit("你好")=="你好" && engine.isEmpty)
        engine.append("ㄋ"); engine.append("ㄧ"); engine.append("ˇ")
        assert(engine.deleteLast() && engine.text == "ㄋㄧ")
        engine.clear(); assert(!engine.deleteLast())
        let smart = PhoneticLexicon(text: "你\tㄋㄧˇ\t950\n妳\tㄋㄧˇ\t720\n泥\tㄋㄧˊ\t800\n好\tㄏㄠˇ\t950\n你好\tㄋㄧˇ ㄏㄠˇ\t2200\n我\tㄨㄛˇ\t980\n要\tㄧㄠˋ\t950\n藥\tㄧㄠˋ\t700")
        let greeting: [ZhuyinKey] = [.group(1), .group(5), .group(2), .group(7)]
        assert(smart.candidates(for: greeting).first?.word == "你好")
        let sentence = greeting + [.group(5), .group(6)]
        assert(smart.candidates(for: sentence).contains { $0.word == "你好我" })
        assert(smart.candidates(for: ["ㄋㄧˊ"]).first?.word == "泥")
        assert(smart.candidates(for: ["ㄋㄧˇ"]).first?.word == "你")
        let yao: [ZhuyinKey] = [.group(5), .group(7)]
        assert(smart.candidates(for: yao).first?.word == "要")
        let medicine = smart.candidates(for: yao).first { $0.word == "藥" }!
        for _ in 0..<8 { smart.recordSelection(medicine, context: "吃") }
        assert(smart.candidates(for: yao, context: "吃").first?.word == "藥")
        assert(smart.suggestions(after: "吃").first?.word == "藥")
        assert(smart.suggestions(after: "你").contains { $0.word == "好" })
        assert(smart.candidates(for: [.symbol("ㄋ")]).contains { $0.word == "你" && $0.completesInput })
        assert(smart.candidates(for: [.symbol("ㄅ"), .symbol("ㄧ"), .symbol("ㄏ"), .symbol("ㄠ")]).isEmpty)
        var typo = greeting
        typo[0] = .group(0)
        assert(smart.candidates(for: typo).contains { $0.word == "你好" && $0.corrected })
        var input = SmartZhuyinInput()
        input.append(.symbol("ˇ")); assert(input.isEmpty)
        input.append(.group(1)); input.append(.symbol("ˇ")); input.append(.symbol("ˊ"))
        assert(input.keys == [.group(1), .symbol("ˊ")])
        assert(input.deleteLast() && input.keys == [.group(1)])
        input.clear(); assert(input.isEmpty && !input.deleteLast())
        let suite = "NineGridTests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let persisted = PhoneticLexicon(text: "藥\tㄧㄠˋ\t700", defaults: defaults)
        persisted.recordSelection(medicine, context: "吃")
        let restored = PhoneticLexicon(text: "", defaults: defaults)
        assert(restored.candidates(for: yao).first?.word == "藥")
        defaults.removePersistentDomain(forName: suite)
        if CommandLine.arguments.count > 1 {
            let text = try! String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
            let started = Date()
            let full = PhoneticLexicon(text: text)
            let loaded = Date()
            var longest = 0.0
            for keys in [greeting, sentence, yao, Array(repeating: ZhuyinKey.group(5), count: 12)] {
                let begin = Date()
                _ = full.candidates(for: keys)
                longest = max(longest, Date().timeIntervalSince(begin))
            }
            assert(full.candidates(for: ["ㄋㄧˇ", "ㄏㄠˇ"]).contains { $0.word == "你好" })
            var usage = rusage()
            getrusage(RUSAGE_SELF, &usage)
            print("Full lexicon rows: \(text.split(whereSeparator: \.isNewline).count), load seconds: \(loaded.timeIntervalSince(started)), maximum query seconds: \(longest), peak MiB: \(Double(usage.ru_maxrss) / 1048576)")
            assert(longest < 1.0, "Typing queries must remain responsive")
        }
        print("PASS: ambiguous keys, continuous phrases, tones, completion, corrections, contextual learning, persistence, delete")
    }
}

