# 憑證文件

這個目錄包含用於建立伺服器憑證的腳本和工具。

## 快速開始

若要建立一組預設的測試憑證，只需執行：

```bash
$ ./bootstrap
```

這個指令會根據範例設定檔建立：
- 自簽憑證機構（root CA）
- 伺服器憑證

## 主要功能

- 支援 EAP-TLS、PEAP 和 EAP-TTLS 認證
- 自動包含 TLS 網頁伺服器所需的擴充金鑰使用（EKU）欄位
- 提供多種憑證格式：
  - Windows 系統：使用 .p12 或 .der 格式
  - Linux 系統：使用 .pem 格式

## 建立憑證

### 建立根憑證（CA）
1. 編輯 `ca.cnf`，設定：
   - 憑證有效期限（default_days）
   - CA 憑證密碼
   - 組織資訊（國家、州/省等）
2. 執行 `make ca.pem` 建立 CA
3. 執行 `make ca.der` 建立 Windows 使用的格式

### 建立伺服器憑證
1. 編輯 `server.cnf`
2. 執行 `make server`

### 建立客戶端憑證
1. 編輯 `client.cnf`
2. 執行 `make client`

## 注意事項

- 建議在測試環境中先使用測試憑證
- 正式環境建議使用私有 CA
- 確保根憑證安裝在需要進行 EAP-TLS、PEAP 或 EAP-TTLS 認證的客戶端機器上
- 憑證相容性已在所有主要作業系統上測試通過
