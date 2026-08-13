# M9A 日志、诊断与错误脱敏

`DiagnosticPrivacy` 是 Native -> ArkTS 异常、HiLog 错误摘要和诊断产物的单一
脱敏边界。它从异常中只保留稳定的类别、可重试性和可选的数字错误码；原始异常文本
不会进入 UI 状态、HiLog 或诊断包。

| 数据/路径 | M9A 约束 | 保留的排障信息 |
| --- | --- | --- |
| Native 异常到 UI | 识别 `timeout`、`permission`、`unavailable`、`invalid_request` 或 `native_error`；URL、令牌、密码、私钥、请求头和查询参数均不保留。 | 原有失败前缀、分类和数值 code；调用方的重试入口不变。 |
| HiLog 异常 | 仅记录分类、code 和 retryable；不记录平台 `message`。 | 操作名、稳定分类和数值 code。 |
| `diagnostic-*-events.ndjson` | 每个文件最多 100 条，且最多 24 KiB；事件字段继续限制为安全 token 和数字 code。 | 时间、来源、事件、阶段、数值 code。 |
| 诊断报告 | report JSON 最多 128 KiB、summary 最多 24 KiB；超限会走既有“生成失败”结果并清理临时文件。 | 原有已脱敏设备/版本、计数器、状态分类和事件摘要。 |

诊断报告继续排除 raw HiLog、完整 tsnet/backend snapshot、身份字段、网络地址、端点、
完整授权 URL、敏感查询参数、请求头、Token、私钥和密码。报告格式、缓存位置、权限、
分享方式和 24 小时保留语义未改变；M9C 才处理可恢复文件位置，M9B 才处理 HTTP 风险
确认。

回退：删除 `DiagnosticPrivacy.ets` 并恢复三个异常呈现/日志调用即可；诊断事件和报告
均未改变文件名、schema、位置或用户数据格式。
