import SwiftUI

@main
struct NineGridZhuyinApp: App {
    var body: some Scene { WindowGroup { SetupScreen() } }
}

private struct SetupScreen: View {
    @State private var text = ""
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("九宮格注音", systemImage: "keyboard")
                        .font(.largeTitle.bold()).foregroundStyle(.blue)
                    Text("iPhone 繁體中文注音九宮格鍵盤")
                        .foregroundStyle(.secondary)
                    Text("啟用鍵盤").font(.title2.bold())
                    instruction("1", "打開 iPhone「設定」")
                    instruction("2", "選擇「一般」→「鍵盤」→「鍵盤」")
                    instruction("3", "點「加入新鍵盤」→「九宮格注音」")
                    instruction("4", "開啟 LINE 或備忘錄，點按 🌐 切換鍵盤")
                    Button {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else {return}
                        UIApplication.shared.open(url)
                    } label: {
                        Label("開啟 App 設定", systemImage: "gearshape")
                            .frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent)
                    Text("試打區").font(.title3.bold())
                    TextEditor(text: $text)
                        .frame(height: 140)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Label("離線輸入，不收集輸入內容，也不要求「允許完整取用」。",systemImage:"lock.shield")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("目前是九宮格注音基礎版：先點主鍵群組，再選擇注音，最後選擇候選字。密碼欄和部分 App 會由 iOS 自動切回系統鍵盤。")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding()
            }
            .navigationTitle("鍵盤設定")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    private func instruction(_ number: String, _ words: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).foregroundStyle(.white).font(.headline)
                .frame(width: 28, height: 28).background(.blue, in: Circle())
            Text(words).padding(.top,4)
        }
    }
}
