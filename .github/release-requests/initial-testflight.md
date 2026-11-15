# 九宮格注音首次 TestFlight 編譯請求

由 GitHub Actions `iPhone archive and TestFlight` 在本檔首次加入 main 時自動執行一次。

- 簽署／Apple 身分認證僅使用已儲存在 GitHub Actions Secrets 的資料，不會存入 Git 原始碼。
- 預期產生包含鍵盤擴充功能的 IPA 並上傳 App Store Connect TestFlight。
- 這筆提交只代表「已觸發發佈嘗試」，不保證 Apple 簽署或上傳成功；以 Actions 執行結果為準。
