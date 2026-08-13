# M0 状态与生命周期行为基线

本文件固化当前代码的观察结果，不改变生产行为。后续切片必须逐项保持或以 fixture、
结构化日志和真机 probe 证明兼容。

## 状态转换

| 范围 | 入口 | 状态/顺序 | 幂等与过期完成规则 |
| --- | --- | --- | --- |
| VPN | `onCreate` → 创建 TUN → 后端启动 | stopped → starting → NeedsLogin/Running；停止请求经 disconnecting → stopped/failed | `destroying` 时不再创建；替换 VPN 需要显式批准文件；重连配置 Promise 在停止时先取得、再写入 handoff。 |
| Tailsend 发送 | 定时器扫描 send/cancel 文件 | queued → sending → completed/failed；取消为 failed/cancelled 原因 | 单一 `taildropSendInFlight` 与 requestId 防止并发完成覆盖。 |
| Tailsend 接收 | 定时器扫描 receive 文件 | 请求校验 → 暂存 → success/failed | 单一 `taildropReceiveInFlight`；路径必须是 inboxRoot 下 requestId 对应文件。 |
| 通知 | 收件箱快照变化 | progress → save/open/later Want | 已通知 key 清单与初始化标记避免同一快照重入重复通知。 |

## 生命周期与所有者

| 对象 | 所有者 | 注册/启动 | 注销/停止 | 销毁后规则 |
| --- | --- | --- | --- | --- |
| `VpnBackgroundTaskManager` | `EntryAbility` | `onCreate` | `onDestroy` | 页面/Tabs 隐藏不停止核心 VPN。 |
| `taildropRequestTimer` / `taildropIncomingTimer` | `TailscaleVpnExtensionAbility` | Extension `onCreate` 后 | `onDestroy` 清除 | `destroying` 阻断后续 VPN/异步更新。 |
| Tailsend incoming watcher | Go backend controller | backend start | stop/cancel generation | generation 变化后旧 watcher 结果无效。 |
| 通知 Want | `EntryAbility` | `onCreate` 与 `onNewWant` | 无持久监听 | 同一 Want 只写入既有 AppStorage 键，通知重入不得创建后台实例。 |

## 可重复验证场景

1. 重复进入/退出：启动 Ability 两次、切换 Tab 后监听/定时器数量不增加。
2. 销毁后 Promise：停止 VPN 后延迟完成的 config Promise 不能重新创建 TUN 或覆盖后续状态。
3. 通知重入：同一 open/save/later Want 经 `onCreate` 或 `onNewWant` 都只写入既有四个参数语义。
4. 后台恢复：`onBackground` 保持后台任务；`onForeground` 恢复可见 UI，不停止已启动 VPN/传输。

设备验证命令和前置条件由 `scripts/test.ps1 -List` 统一登记。
