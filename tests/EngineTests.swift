import Foundation
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
        print("PASS: 37 Zhuyin symbols, syllables, candidates, backspace")
    }
}
