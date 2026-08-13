# M2 数据清单与路径边界

本清单记录 M2 开始时的实际数据位置和删除权限。它不迁移、复制、删除或重写任何
用户数据；路径均为运行时由 `Context` 解析的既有私有目录。所有文件目录均由平台
的 `context.filesDir` 提供，当前设备 probe 使用
`/data/app/el2/{appUserId}/base/io.github.tailscaleohos/haps/entry/files` 核验 EL2。
每项均指定唯一所有者和删除权限；没有任何通用缓存清理权限可触及 tsnet 状态。

## 数据类别

| 类别 | 现有位置与格式 | 权威性与所有者 | 生命周期、容量与权限 | 恢复与删除规则 |
| --- | --- | --- | --- | --- |
| 权威 tsnet 状态 | `filesDir/tailscale/control-{sha256[:8]}/`；tsnet 内部状态及 `exit-node-choice`、`network-preferences.json` | 权威；Go `backendController`，由 VPN Extension 传入状态根目录 | 私有 EL2 文件目录；包含设备身份和登录状态，不记录到诊断日志 | 正常启动和升级保留；仅已确认的首次使用诊断重置通过 `ControlServerConfig.reset` 删除根目录 |
| 控制服务器 | `filesDir/control-server.json`，原子写入 | 权威；`ControlServerConfig` | 私有 EL2；单一 URL 和更新时间，无固定容量配额 | 启动读取；仅首次使用诊断重置删除 |
| 登录 | tsnet profile 状态位于 `tailscale/control-*` | 权威；Go tsnet | 私有 EL2；身份、授权和节点状态，禁止日志输出 | tsnet 恢复；注销由后端按既有语义失效登录，首次使用重置才删除目录 |
| 偏好 | tsnet `network-preferences.json`、`exit-node-choice`；ArkData `mesh_arc_home_layout` 偏好库 | 权威；Go backend / `HomeLayoutPreferences` | 前两者私有 EL2；布局偏好由 ArkData 私有库管理 | 网络偏好随 tsnet 恢复；布局偏好仅由用户设置覆盖，不触碰 VPN 状态 |
| 日志 | `diagnostic-ui-events.ndjson`、`diagnostic-vpn-events.ndjson` | 诊断记录；`DiagnosticEventStore` | 私有 EL2；仅结构化事件与数值代码，不含凭据、私钥、密码或完整授权 URL | 读取进脱敏诊断报告；本 M2 不改变保留或删除行为 |
| VPN IPC | `vpn-*-request.json`、`vpn-*-response.json`、`vpn-peers.json`、`vpn-config-summary.txt`、`vpn-probe-status.txt`、peer/Sunshine/media probe 请求响应文件 | 短暂协调状态；UI、VPN Extension 和 Native bridge 各自负责协议端 | 私有 EL2；现有轮询、原子写入和异常语义保持不变 | 由既有请求处理/生命周期清空或覆盖；不得由缓存清理删除 tsnet 状态 |
| Tailsend 待处理状态 | `taildrop-send-request.json`、`taildrop-cancel-request.json`、`taildrop-receive-request.json`、`taildrop-receive-response.json`、`taildrop-targets.json`、`taildrop-inbox-snapshot.json` | 协调状态；BridgeStatus 与 VPN Extension | 私有 EL2；文件路径和 JSON 字段为既有协议 | 由现有发送、取消和接收流程处理；M2 不更改顺序、取消或恢复语义 |
| 历史 | `taildrop-history.json`、`taildrop-history-media/` | 用户可见传输历史；`BridgeStatus` | 私有 EL2；受既有历史 UI 管理 | 仅用户触发的“清除记录”可删除；M2 不移动或修改 |
| 诊断 | `cacheDir/diagnostic-report-*.zip` 及短暂工作目录 | `DiagnosticReportService` | 私有缓存；内容已脱敏 | 成功分享后保留，超过 24 小时由该服务最佳努力清理；工作目录在生成完成或失败后清理 |
| 缓存和临时文件 | `taildrop-outbox/`、`taildrop-inbox-export/` 和内存 peer/media probe 缓存 | VPN Extension / 对应服务 | 私有 EL2 文件缓存；收件箱缓存按既有 7 天阈值清理，内存缓存随进程结束 | 既有 Taildrop 清理只处理所属缓存文件，且不得删除 tsnet 状态；M2 仅标记未来迁移候选 |

## M2 路径适配与验证

- `StoragePaths.filesDir(context)` 原样返回平台解析的 `context.filesDir`；不调用
  `contextConstant.AreaMode`，不创建目录，也不触发 EL1/EL2 重新初始化。
- 唯一迁移调用方是 `VpnBackgroundTaskManager` 对 `vpn-probe-status.txt` 的只读检查。
  调用顺序、文件名、读取 API 与捕获异常后返回 `false` 的语义均未改变。
- `scripts/device-vpn-data-probe.ps1` 和 `scripts/device-exit-node-probe.ps1` 均以同一
  EL2 `filesDir` 模板读取状态文件；它们是已安装设备上路径与安全级别的运行时断言。
- `taildrop-outbox/`、`taildrop-inbox-export/` 和诊断缓存是未来可能迁移的候选；本
  Milestone 不改变它们的位置、格式、容量、所有者或清理时机。

## M9C 可恢复缓存更新

- 新建的 Tailsend 发送侧临时副本从 `filesDir/taildrop-outbox/` 改为
  `cacheDir/taildrop-outbox/`。它们只在用户选定文件后、单次发送完成前存在；原始
  文件、发送请求 JSON 和传输历史不在此目录。
- 旧 `filesDir/taildrop-outbox/` 不迁移、不删除；新版 VPN Extension 对已存在的待发送
  请求继续接受该路径，以便覆盖安装或代码回退处理旧暂存副本。
- `taildrop-inbox-export/`、`taildrop-history-media/`、诊断事件、VPN IPC、控制服务器
  和所有 `tailscale/` tsnet 状态继续使用原位置和原有所有者。任何缓存清理均不遍历
  `tailscale/` 或发起远端 Taildrop 删除。

## 回退和兼容性

回退只需删除 `StoragePaths` 的这一个只读调用并恢复直接字符串拼接。没有数据位置、
持久化格式、用户数据、NAPI/Go ABI、路由参数或 IPC 协议变化。
