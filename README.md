# 九宮格注音 — iPhone 繁體中文鍵盤

本儲存庫含 **iOS App 與第三方 Keyboard Extension**，不是瀏覽器輸入法。支援 iOS 16 起。專案原始碼於 2026-11-15 匯入。

## 功能

- 3×3 九宮格共 37 個注音符號（先按分組，再選符號）。
- 聲調、離線詞庫候選字、刪除、標點、空白、換行。
- 數字及基本英文字母切換、地球儀切換鍵盤。
- 使用 Apple 的 `UITextDocumentProxy` 將文字輸入 LINE、備忘錄及其他允許第三方鍵盤的輸入欄。
- `RequestsOpenAccess=false`，不需要完整取用權限，沒有網路傳送或蒐集輸入資料的程式碼。
- 目前 GitHub 版本包含**小型初始字詞庫**。較大的離線詞庫可以在 GitHub Actions 或本機使用 `python3 scripts/build_lexicon.py` 從 MIT 授權開放資料擴充；如果下載失敗則保留小型離線詞庫；此版本不是已具商用預測選字品質的鍵盤。

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

## 上傳 TestFlight（不用在 iPhone 安裝 Xcode）

專案的 [iPhone archive and TestFlight](.github/workflows/ios-testflight.yml) 是獨立、**手動啟動**的 GitHub Actions；使用 macOS 26 / Xcode 26 或更新版本製作 **已簽署**的 iPhone App 與內嵌 Keyboard Extension，匯出 IPA，並可選擇上傳至 App Store Connect。原來的模擬器編譯工作流程仍會持續執行，並不能代替 iPhone 簽署。

### 必須先完成的 Apple 帳號設定

1. 在 Apple Developer → Certificates, Identifiers & Profiles → Identifiers 確認 **兩個** Explicit App ID（主 App 及鍵盤擴充功能）：
   - 主 App：`com.grost9999.ninegridzhuyin`
   - 鍵盤擴充：`com.grost9999.ninegridzhuyin.keyboard`
   注意 `grost9999` 是 **四個 9**。如果已註冊就不要重複新增。主 App ID 未註冊時不能只靠鍵盤擴充 ID 發佈。
2. 在 [App Store Connect](https://appstoreconnect.apple.com/apps) 新增 iOS App「九宮格注音」，Bundle ID 選主 App `com.grost9999.ninegridzhuyin`。鍵盤擴充功能不用另建 App Store Connect 應用程式。
3. 在 App Store Connect → 使用者與存取權限 → 整合 → App Store Connect API 取得具有適當權限的 API key（Key ID、Issuer ID、一次性下載的 `.p8`）。不要在 GitHub 公開檔案或聊天貼出私鑰。
4. 在本專案 GitHub → Settings → Secrets and variables → Actions → New repository secret 設定：
   - `APPLE_TEAM_ID`：Apple Developer 的 10 碼 Team ID
   - `ASC_KEY_ID`：App Store Connect API Key ID
   - `ASC_ISSUER_ID`：App Store Connect API Issuer ID
   - `ASC_API_KEY_P8`：下載的 **.p8 私鑰全文**（含 BEGIN/END PRIVATE KEY 行），不是檔名或截圖
5. GitHub → Actions → **iPhone archive and TestFlight** → Run workflow。保留 `upload_to_testflight=true` 即會在完成 Apple 正式簽署後上傳；如僅想驗證簽署，可設為 `false` 並從 Actions Artifacts 取得已簽署 IPA。
6. 等 Apple 完成建置處理，再到 App Store Connect → TestFlight 啟用內部測試者，使用 iPhone TestFlight 安裝主 App。在 iPhone「設定 → 一般 → 鍵盤 → 鍵盤 → 加入新鍵盤」啟用「九宮格注音」。

### 重要限制

- GitHub Actions **不能自行創造或繞過 Apple 開發者身分、憑證及 Provisioning Profile**。首次簽署若出現 certificate/profile 權限或缺失，必須在 Apple Developer 帳號完成相應權限／簽署設定後重新執行；失敗不代表 IPA 已上傳。
- 自動發佈採 Xcode 的 automatic signing 與 App Store Connect API 認證。輸出成功不等於 App 已上架；TestFlight 還需要 Apple 處理與測試者啟用。
- App Store icon 由 `swift scripts/generate_icon.swift` 產生**不透明 1024×1024 PNG**，不連網、不存取個人資料。若在本機 Xcode 開專案，先執行此命令再執行 `xcodegen generate`。
- 因為這是首次發佈，請在 TestFlight 實機檢查鍵盤高度、詞庫載入、九宮格選鍵、切換與 LINE 等輸入框。詞庫與智慧選字仍是基礎版，勿視為已經過商用完整測試。
