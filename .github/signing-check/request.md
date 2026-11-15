# Apple API 授權安全診斷

確認 GitHub Secrets 可否讀取 App Store Connect 資訊，以及主 App / 鍵盤擴充的 Bundle IDs 和 Provisioning API。

診斷只執行唯讀 GET，不產生或下載 Apple 憑證，不會顯示私鑰或 JWT，也不會自動嘗試上架。

- 使用更新後的 GitHub 金鑰再次測試：2026-11-15（不輸出金鑰內容）。
