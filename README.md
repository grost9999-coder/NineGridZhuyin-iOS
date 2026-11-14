# 九宮格注音 — iPhone 繁體中文鍵盤

本儲存庫含 **iOS App 與第三方 Keyboard Extension**，不是瀏覽器輸入法。支援 iOS 16 起。專案原始碼於 2026-11-15 匯入。

## 功能

- 3×3 九宮格共 37 個注音符號（先按分組，再選符號）。
- 聲調、離線詞庫候選字、刪除、標點、空白、換行。
- 數字及基本英文字母切換、地球儀切換鍵盤。
- 使用 Apple 的 `UITextDocumentProxy` 將文字輸入 LINE、備忘錄及其他允許第三方鍵盤的輸入欄。
- `RequestsOpenAccess=false`，不需要完整取用權限，沒有網路傳送或蒐集輸入資料的程式碼。
- 目前 GitHub 版本包含**小型初始字詞庫**。較大的約 2,000 筆離線詞庫仍保留在先前 ChatGPT 對話提供的 Xcode ZIP 中，尚待同步；此版本不是已具商用預測選字品質的鍵盤。

## 編譯

GitHub Actions 於 main 分支提交後，用 macOS runner 安裝 [XcodeGen](https://github.com/yonaskolb/XcodeGen)、產生 `NineGridZhuyin.xcodeproj` 並以未簽署方式編譯 iOS Simulator App + Keyboard Extension。此工作流程**不會**產生可直接安裝 iPhone 的 IPA。

在有 Xcode 的 Mac：

```bash
brew install xcodegen
xcodegen generate
open NineGridZhuyin.xcodeproj
```

於 Xcode 主 App 和 Keyboard Extension 兩個 Target 指定你自己的 Apple Developer Team、調整 Bundle Identifier，連接 iPhone 執行，或完成 Distribution 簽署上傳 App Store Connect／TestFlight。尚未完成 Apple 代碼簽署、實機測試或 TestFlight 發佈。

## 使用

安裝已簽署 App 後：iPhone「設定 → 一般 → 鍵盤 → 鍵盤 → 加入新鍵盤 → 九宮格注音」，再到 LINE／備忘錄按 🌐 切換。密碼等欄位會依 iOS 規則改用系統鍵盤。

## 限制

這是功能性基礎版，注音採群組二段式選鍵。尚未完成使用者常用詞學習、連續滑行輸入、完整聲調智慧辨識與商用級詞頻排序。是否能在真機穩定使用，仍以 Xcode 實機測試為準。
