# M9B HTTP 自定义后端风险确认

`SettingsPreferencesGateway.requiresHttpControlServerRisk` 是 M9B 的纯策略边界。
只有候选地址为 `http://`，且它不是当前已确认的同一地址时，`BridgeStatus` 才显示
独立的 HTTP 风险对话框。用户必须先点击“确认后端服务器”，再在风险对话框中选择
“仍然保存 HTTP 后端”才会调用现有 `confirmControlServer` 持久化流程。

| 场景 | 是否显示 HTTP 风险确认 | 写入/后端行为 |
| --- | --- | --- |
| 新 HTTP 地址 | 是 | 仅在二次确认后沿用原子写入与既有 stop/restart 流程。 |
| 已保存 HTTP 同地址再次保存 | 否 | 保持既有显式保存语义；不在读取或启动时静默写入。 |
| 已保存 HTTP 改为另一 HTTP 地址 | 是 | 取消时不写入、不停止或启动后端，也不覆盖旧配置。 |
| 新 HTTPS 地址或默认 Tailscale HTTPS 地址 | 否 | 沿用现有保存、失败和重启语义。 |
| 冷启动、热启动、加载已保存 HTTP | 否 | `loadControlServer` 仅按既有字段读取，不弹窗、不改写状态目录哈希。 |

存储字段 `controlURL`、`confirmed`、`updatedAtMs`，文件名 `control-server.json`，URL
normalize 规则、默认 HTTPS 地址、状态目录哈希、HTTP/HTTPS 接受范围、日志、路径和
权限均未改变。M9B 不禁止 HTTP；风险确认只影响新 HTTP 保存的 UI 时机。

Cold/hot startup reads an existing HTTP setting without showing this dialog or
rewriting the configuration.

回退：删除该风险策略调用、风险对话框资源、fixture/lifecycle 文档与 M9B suite
注册即可。持久化格式和既有已保存 HTTP 配置始终可读。
