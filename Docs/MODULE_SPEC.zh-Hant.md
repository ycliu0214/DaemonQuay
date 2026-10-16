[**繁體中文**](MODULE_SPEC.zh-Hant.md) | [English](MODULE_SPEC.md)

# DaemonQuay 模組開發規範 · Module API v1

**適用版本：** v0.10.4（v0.10.2 之後模組執行行為未變）。本文描述**已實作的契約**，不保證每種未來服務類型都已內建 Adapter。

**責任範圍：** Core 負責 GUI、模組搜尋與呼叫、結果顯示；Module 負責 `start`、`stop`、`status`，且必須正確辨識並停止自己管理的服務。服務業務功能健康度並非 Core 的責任。第三方模組不強制使用 launchd。

## 1. 模組目錄、安裝與啟用

```text
~/.local/share/DaemonQuay/modules/example/
├── module.json          # 必填
├── module-control       # 必備可執行控制程式；名稱由 module.json 決定
└── service.json         # 選用；僅共用 launchd 執行器需要
```

內建 oMLX／Caddy 位於 `DaemonQuay.app/Contents/Resources/Modules/{omlx,caddy}/`。內建 ID 優先，外部模組不得覆蓋。請勿直接修改已簽署 App Bundle，避免破壞簽章或在更新時遺失模組。

**手動安裝：** 先獨立測試工具的標準啟停；複製 `module.json`、可執行控制程式及必要支援檔案到外部模組目錄；確認 `test -x` 通過；把模組 ID 加到 `enabled-modules.json` 的 JSON 字串陣列，保留舊項目；重新開啟 GUI 載入。模組只能在服務已停止時更新、停用或移除。目前**沒有** GUI Installer、沙箱、模組更新器或 CLI。啟用第三方可執行檔等同信任其以你的使用者權限運作。

## 2. `module.json` 正式欄位

```json
{
  "apiVersion": 1,
  "id": "example",
  "name": "Example Server",
  "executable": "module-control",
  "symbol": "shippingbox",
  "stopOrder": 50,
  "startTimeoutSeconds": 20,
  "stopTimeoutSeconds": 60,
  "statusTimeoutSeconds": 4,
  "supportsValidate": false,
  "settings": [
    {"key":"executable","type":"string","labels":{"zh-Hant":"執行檔","en":"Executable"}},
    {"key":"port","type":"integer","labels":{"zh-Hant":"連接埠","en":"Port"}}
  ]
}
```

| 欄位 | 必填 | 目前實際限制 |
|---|---|---|
| `apiVersion` | 是 | 只接受整數 `1` |
| `id` | 是 | 必須等於模組資料夾名稱，`^[a-z][a-z0-9-]{1,39}$`，2–40 字元，不能重複 |
| `name` | 是 | 去除空白後非空，最多 80 字元 |
| `executable` | 是 | 模組資料夾內的**相對路徑**、一般可執行檔；解析 symlink 後仍須位於模組目錄內 |
| `symbol` | 否 | SF Symbol 名稱，預設 `shippingbox`；目前不驗證圖示是否存在 |
| `stopOrder` | 否 | 整數，預設 50；用於「停止全部後退出」的升冪順序，與顯示排序無關 |
| `startTimeoutSeconds` | 否 | 1–120 秒，預設 20；啟動命令和後續狀態確認逾時 |
| `stopTimeoutSeconds` | 否 | 10–300 秒，預設 60；停止命令和後續狀態確認逾時 |
| `statusTimeoutSeconds` | 否 | 1–10 秒，預設 4；`validate` 逾時為此值加 10 秒 |
| `supportsValidate` | 否 | Boolean，預設 false；啟用後設定頁呼叫 `validate` |
| `settings` | 否 | 欄位陣列，預設空；目前 GUI **僅支援 `string`、`integer`** |

`settings` 每個欄位必須具有 `key`、`type`、`labels`。`key` 符合 `^[A-Za-z][A-Za-z0-9]*$`，且模組內唯一；`labels` 是以語系代碼索引的字串表，介面會回退英文或 key。GUI 目前不通用支援 `min`、`max`、`default`、`required`、secret 類型或條件表單；即使自行加進 JSON 也不會自動生效，請在模組驗證設定。

Registry 搜尋 App 內建及使用者模組，拒絕無效 manifest、可執行權限或重複 ID；未啟用者不顯示於正常控制介面。`enabled-modules.json` 必須是字串陣列；缺失或無效時，為相容性會預設啟用內建 `omlx`、`caddy`。**停用執行中的模組可能使其無法從 GUI 管理；先停止才可停用。**

## 3. 執行檔通訊契約

DaemonQuay 以模組目錄作工作目錄，每次啟動一個**短暫存在的**控制程序，並且恰好傳入一個引數：

```text
module-control status
module-control start
module-control stop
module-control validate     # 只有 supportsValidate = true
```

環境變數：

```text
DAEMONQUAY_MODULE_ID    模組 ID
DAEMONQUAY_MODULE_DIR   模組絕對路徑
DAEMONQUAY_DATA_DIR     DaemonQuay 使用者資料目錄絕對路徑
```

其餘環境繼承自 GUI，**不能假設** Terminal 的 PATH、alias、shell 初始化檔案。請使用絕對執行檔路徑。

控制程式必須在 **stdout 輸出恰好一個 UTF-8 JSON 物件**，上限 65,536 bytes，例如：

```json
{"state":"running","message":"Running (PID 1234)"}
```

`state` 必填，支援 `running`、`stopped`、`external`、`error`；`message` 選填，其他 JSON 欄位目前忽略。診斷文字寫到 stderr，不要污染 stdout。輸出後控制程式必須退出，真正的服務則依自身後端繼續執行。無長期 IPC／串流通道。

**退出碼：** 正常狀態回應需使用作業系統退出碼 **0**；即使 `status` 為 `stopped` 也必須 exit 0。非 0 退出碼一律視為失敗。Core 將 `running`、`stopped`、`external`、`error` 內部映射到 0、1、3、2，但這不是 Module Controller 的程序退出碼。

### 四項操作語義

- `status`：快速且無副作用。自己管理的服務存活回 `running`；確認已停止且無已知衝突回 `stopped`；外部程序或資源衝突回 `external`；無法可靠辨識回 `error`。GUI 約每 2 秒查詢一次。
- `start`：必須盡可能冪等，先檢查是否已在執行或有外部衝突；不能重複啟動自己的服務，也不能擅自接管外部程序。Core 會持續輪詢 `status` 到 `running`、錯誤或逾時；這不保證服務業務功能已就緒。
- `stop`：只對模組自己管理的服務使用其標準正常關閉方式，並確認退出；不要單純因為送出訊號就聲稱成功。Core 輪詢到 `stopped` 或逾時，禁止誤殺外部程序。
- `validate`：選用；不得啟動／停止服務。內建執行器成功時回 `{"state":"stopped","message":"Configuration valid"}`；Core 對 `running` 或 `stopped` 且 exit 0 視為驗證通過。

### 錯誤、逾時與競態

回 `{"state":"error","message":"..."}`、退出碼非 0、格式錯誤、stdout 超過大小上限、空白輸出或混雜非 JSON 訊息，均會造成操作失敗。逾時終止的是**控制命令**，不必然終止實際服務。`status` 若為 `error` 或 `external`，啟動／停止將依目前控制邏輯拒絕或中斷，防止錯誤接管。

Core 有啟停前狀態查詢、後續輪詢，以及 GUI 單一實例鎖；但**沒有**可涵蓋其他 GUI／CLI／Terminal 的通用跨程序原子鎖，模組作者仍應正確驗證程序身分，避免競態與外部誤殺。

## 4. 使用者設定與日誌

模組設定以 `~/.local/share/DaemonQuay/settings.json` 裡的模組 ID 作為頂層 key（例如 `omlx`、`caddy`）；GUI 儲存會保留不相關模組的內容與未知欄位。服務非 `stopped` 時不允許修改。若 `supportsValidate` 為 true，GUI 將寫入候選設定、呼叫 `validate`，失敗時嘗試回復原值；此流程不是跨外部程序的完全交易性保證。

GUI 預設讀取 `~/.local/share/DaemonQuay/logs/<id>/log.log` 與 `error.log`，可回退讀取舊版平面日誌；**Core 不會自動替任意第三方模組重導輸出**，模組作者必須自己安排日誌位置或告知不提供。stdout／stderr 是輸出串流，不是一般／錯誤等級分類。

顯示排序存放在 `service-order.json`，與 `module.json` 的 `stopOrder` 無關。API Key 與密碼不應放在命令列參數或日誌；目前 Core **不是密鑰儲存庫**，第三方控制程式也未沙箱化。權限加固時不能意外移除模組可執行檔的執行位元。

## 5. 選用的共用 launchd 執行器：`service.json`

oMLX 與 Caddy 共用 `Sources/ModuleHost/main.swift` 編譯出的 `module-control`。第三方模組可以採用它，但**只有採用這份共用執行器時**才必須提供 `service.json`；自訂執行檔可以使用其他配置方式。

```json
{
  "apiVersion": 1,
  "launchLabel": "dev.daemonquay.example",
  "start": ["${executable}","serve","--port","${port}"],
  "stopStrategy": "signal",
  "portKey": "port",
  "timeoutKey": "shutdownTimeout",
  "requiredDirectories": ["${workspace}"],
  "requiredFiles": [],
  "preflight": null
}
```

| 欄位 | 共用執行器中的語義 |
|---|---|
| `apiVersion` | 必填，整數 1 |
| `launchLabel` | 必填，必須是 `dev.daemonquay.<module-id>` |
| `start` | 必填、非空引數陣列；首項展開後必須是絕對執行檔路徑，由 launchd 執行，不經 Shell |
| `stopStrategy` | 僅 `signal` 或 `commandThenSignal` |
| `stopCommand` | `commandThenSignal` 時必填、非空陣列；停止命令失敗才使用 SIGTERM 備援 |
| `preflight` | 選填，啟動前先執行的驗證命令；非 0 則不啟動 |
| `portKey` | 選填，指向設定中的整數 TCP Port，以 `lsof` 輔助偵測衝突；缺省則不檢查 |
| `timeoutKey` | 選填，指向設定中的優雅停止秒數，10–300，預設 60 |
| `requiredDirectories`、`requiredFiles` | 選填，必須存在的路徑陣列 |

陣列每個引數分別以 `${field}` 從設定插值。插值結果若以 `~/` 開頭，會展開使用者家目錄；**不提供 Shell 解譯**，不支援環境變數展開、glob、pipe、redirection、命令替換或 PATH 搜尋。複雜前置工作請用獨立的可執行包裝腳本，最後以 `exec` 替換成前景服務程序。

共用執行器產生 `agents/` 內的 plist，設定 `RunAtLoad=false`、`KeepAlive=false`、`logs/<id>/` 的 stdout／stderr 路徑；透過 `launchctl bootstrap`、`kickstart` 啟動，確認 Job PID，對當前帳號的 `gui/<uid>` domain 操作。沒有登入後自動啟動、崩潰自動重啟或健康檢查。SSH 若沒有適當 GUI domain 可能無法使用。

**`commandThenSignal` 注意：** 只有停止命令執行**失敗**才回退到 SIGTERM；如果停止命令回報成功，但受管理 PID 沒有退出，現有實作會逾時，不會自動追加訊號。

## 6. 不同啟動、存活檢查及停止策略範例

**下列為設計與實作參考，不表示 Core 已內建所有 Adapter。**

| 類型 | 啟動 | 存活確認 | 正常停止 | 限制 |
|---|---|---|---|---|
| 前景常駐 Server | launchd 直接啟動 | 受管理 Job PID | SIGTERM | oMLX 為現有範例；需要前景模式 |
| 原生設定檔 Server | `server run --config ...` | 受管理 Job PID | 工具原生停止 CLI | Caddy 為現有範例；Core 不修改原生設定檔 |
| 複雜啟動腳本 | 前置設定後 `exec server ...` | 被 exec 取代的程序 PID | SIGTERM 或工具原生 CLI | 背景啟動後 script exit 會破壞 PID 追蹤 |
| 自帶 stop CLI 的程式 | 前景啟動 | Job 或經驗證的 PID | 正式 stop CLI + 確認退出 | 不可僅憑停止指令退出碼認定已關閉 |
| 自有 Supervisor | 模組自行呼叫管理 API | Supervisor 的實例狀態 | Supervisor Stop API | 共用 launchd host 不支援，需自訂 controller |
| Docker／VM | 對外部管理器發啟動請求 | Inspect／管理器狀態 | 外部 shutdown API | `docker start` 命令退出不代表容器停止 |
| PID File | 自訂啟動流程 | PID + 程序身分＋防 PID 重用 | 官方停止命令，確認退出 | `kill(pid,0)` 本身不足以驗證歸屬 |
| Port 偵測 | 需額外所有權判斷 | Port 主要辨識衝突 | 不可任意殺監聽 Port 的程序 | Port 存在不能證明是受管理實例 |

### 包裝腳本範例

```zsh
#!/bin/zsh
set -e
export EXAMPLE_CONFIG="$HOME/.config/example/config.json"
cd "$HOME/ExampleWorkspace"
exec /absolute/path/to/example-server --config "$EXAMPLE_CONFIG"
```

`service.json` 的 `start` 指向這支腳本的**絕對路徑**。`module.json` 的 `executable` 仍指向短暫執行的控制程式。不要直接把 `$HOME`、`$(...)`、`&&`、重導向等 Shell 語法放入 JSON 引數陣列並期待展開。

### 自訂控制程式流程（偽程式碼）

```text
status:
  若已驗證屬於模組自己的實例且存活 → running
  若有外部資源衝突 → external
  否則若已確認停止 → stopped
  否則 → error
start:
  若非 stopped，回報目前狀態
  依工具標準流程啟動，回報 status()
stop:
  若 external，不得接管
  只對自己管理的實例提出正常停止要求
  等待退出或交給 Core 輪詢，回報 status()
```

PID、程式名稱、Port 或一次啟動命令成功，單獨都不足以保證程序所有權。

## 7. 模組開發者驗收清單

- [ ] 已在 DaemonQuay 以外測試完全相同的啟動與正常停止方式。
- [ ] 模組 ID、目錄與 manifest 合法；控制程式位於模組內且有執行權限。
- [ ] `status` 能辨識自己管理的實例、停止、外部衝突與無法確認的情況。
- [ ] `start` 冪等，不會重複開啟服務。
- [ ] `stop` 不會誤殺外部程序，能確認退出並回報逾時。
- [ ] stdout 僅一個有效 JSON；正常狀態的 OS exit code 是 0。
- [ ] `validate`（若提供）不啟停服務或擅改無關設定。
- [ ] GUI 關閉／重開後仍可辨識自己管理的服務。
- [ ] 設定可保存；密鑰不意外出現在日誌與命令列。
- [ ] 日誌來源有文件，模組僅在停止後移除。
- [ ] 測試啟動／停止延遲、依賴缺失及服務異常退出。
- [ ] 不自動啟用來源不明的可執行檔。

## 8. 參考實作與測試

- `Modules/omlx/module.json`、`Modules/omlx/service.json`。
- `Modules/caddy/module.json`、`Modules/caddy/service.json`。
- `Sources/ModuleHost/main.swift`：共用原生 launchd 執行器。
- `Sources/DaemonQuay/Plugins/PluginRegistry.swift`：Manifest 與路徑驗證。
- `Sources/DaemonQuay/Plugins/PluginRuntime.swift`：操作呼叫、stdout 協定與逾時。
- `Tests/test_modules.py`：可跨平台執行的描述檔測試。

測試腳本不能證明所有模組都在 macOS launchd 中正確啟停；真正的停止策略與程序辨識仍需模組開發者做實機整合測試。

### 選用引數群組（內附的 launchd 執行器）

`service.json` 可透過 `optionalStartArguments` 指定
`{"whenNonEmpty":"settingKey","arguments":["--flag","${settingKey}"]}`。
當設定值為空字串時，整組引數不會傳入。內建 oMLX 模組用此機制讓 SSD cache 預設停用。
這是共用 launchd 執行器的擴充欄位，不屬於所有第三方模組必須實作的 API。
