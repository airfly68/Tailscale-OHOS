# Milestone 13：旧实现独立清理

## 目标与边界

M13 只清理 M3-M12D 完成后仍留在生产源码中的、经静态引用检查确认没有消费者的旧 UI 方法、状态、Builder 和局部适配方法。它不改路由、协议、持久化格式、用户数据位置或业务状态转换。

`BridgeStatus.ets` 仍是 `AppShell` 的实际状态宿主和页面生命周期宿主，因此本里程碑不删除它，也不把它替换成空壳。BridgeStatus remains active as that host. `StreamingModels.ets` 继续作为 M1 兼容导入出口；`HomeLayoutPreferences.ets` 和 `LegacyConnectedHomeHeader.ets` 继续服务现有偏好/兼容路径。VPN Extension 仍使用的 `backendPeerConnectivityAsync` 也保留，清理的只是 BridgeStatus 中无消费者的 UI 连接性适配。

## 清理内容

- 删除 BridgeStatus 中未被调用的旧连接按钮、出口节点按钮、Transfer 概览、旧接收/文本预览面板、旧刷新方法、旧状态文案和无消费者 Taildrop/peer-connectivity 状态。
- 删除 `PeerPathService.probeConnectivity` 与 `enqueueConnectivity`；现有 `probe` 路径及其缓存、取消和 Extension 文件协议保持不变。
- 以 `fixtures/m13/legacy-cleanup-contracts.json` 固化删除清单、兼容保留项、唯一监听器所有权和 AppShell 生命周期边界；`scripts/test.ps1 -Suite M13LegacyCleanup` 在清理后执行静态依赖检查。

## 验收证据

The pre-cleanup static scan and the post-cleanup fixture, full-test, build and probe results are recorded in the M13 entry of `STATUS.md`. Engine/Backend, VpnData, ExitNode and other unavailable-device items are marked not executed rather than passed. The cleanup deletes no user data, so no migration or rollback window is required.

## 回退

M13 文件变更保持独立；恢复被删除的旧源码和移除 M13 suite/fixture/documentation 即可回退，不需要用户数据回滚。
