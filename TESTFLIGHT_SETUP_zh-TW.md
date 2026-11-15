# 九宮格注音：iPhone / TestFlight 發佈檢查表（繁體中文）

## 目前已完成
- iOS 原生主 App 與 Keyboard Extension 的 GitHub 原始碼。
- 主 App Bundle ID：`com.grost9999.ninegridzhuyin`
- 鍵盤 Bundle ID：`com.grost9999.ninegridzhuyin.keyboard`
- 不含金鑰的 iOS 模擬器編譯流程：`.github/workflows/ios-simulator-check.yml`。
- 手動啟動的正式封存及 TestFlight 工作流程：`.github/workflows/ios-testflight.yml`。
- 已建立 App Store Connect App 紀錄（使用者先前提供截圖）。

## 上傳前必要條件（要在 GitHub 網頁上設定，不能放在程式碼）

開啟 https://github.com/grost9999-coder/NineGridZhuyin-iOS/settings/secrets/actions

每次點 `New repository secret`，新增下列 **Actions Repository Secrets**：

| Name | Secret value 來源 |
| --- | --- |
| `APPLE_TEAM_ID` | Apple Developer 帳號的 10 碼 Team ID（Membership 會員資格資料） |
| `ASC_KEY_ID` | App Store Connect → 使用者與存取權限 → 整合 → App Store Connect API 的團隊金鑰 ID |
| `ASC_ISSUER_ID` | 同一個 API 金鑰頁面的 Issuer ID |
| `ASC_API_KEY_P8` | 對應上述 Key ID 的 `.p8` 私鑰全文，含 BEGIN/END PRIVATE KEY |

### 安全提醒
- 不要把 `.p8` 私鑰貼入 ChatGPT、GitHub Issue、README、程式碼檔或公開網頁。
- 私鑰若先前下載過，可在 iPhone「檔案」App 裡找 `AuthKey_*.p8`；Apple 不提供重複下載。
- 現有其他 App 正在使用的 API 金鑰不要任意撤銷，否則會影響其他上架流程。
- App Store Connect Team API Key 的權限可能涵蓋同一團隊的其他 App，請謹慎授權。
- GitHub Actions Secrets 儲存後無法重新查看內容；若輸入錯誤，重新更新該 Secret。

## 四筆都設好後執行
1. 開啟 https://github.com/grost9999-coder/NineGridZhuyin-iOS/actions/workflows/ios-testflight.yml
2. 點選 `Run workflow`，分支選 `main`。
3. `upload_to_testflight` 保持 `true`，執行流程。
4. 綠色成功只表示工作流程已執行，仍須進 App Store Connect → TestFlight 檢查 Apple 是否處理完成。
5. 如果簽署失敗，點進失敗步驟查錯誤。常見原因是憑證、簽署權限或 Provisioning Profile 不齊；不能只憑 API 金鑰就保證成功。

## 安裝與啟用
Apple 處理完成後，在 App Store Connect 的 TestFlight 把自己加入內部測試，iPhone 上使用 TestFlight 安裝 App。
開啟 iPhone 設定 → 一般 → 鍵盤 → 鍵盤 → 加入新鍵盤 → 九宮格注音。
輸入密碼時 iOS 通常會切回 Apple 系統鍵盤。

## 若 GitHub 雲端簽署無法自行建立憑證
目前正式工作流程用 Xcode automatic signing + App Store Connect API Key。某些帳號可能需要先準備 Apple Distribution 憑證（含相符的私鑰）及兩個 target 對應的設定描述檔，再安全匯入 GitHub Secrets；請依 GitHub Actions 真實錯誤訊息處理。不要上傳未簽署 IPA 到 TestFlight。
