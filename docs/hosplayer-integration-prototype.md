# MeshArc × HosPlayer 联动协议原型

## 当前状态

MeshArc 已实现协议生成、参数安全校验和离线自检，但默认不会真正拉起 HosPlayer。
原因是 HosPlayer 尚未公开稳定的 Deep Link 或 App Linking 接口。待双方确认正式
URI 后，只需更新 `HosPlayerLauncher.ets` 中的协议地址并启用开关。

## URI 原型

```text
hosplayer://server/add
  ?protocolVersion=1
  &type=jellyfin
  &url=http%3A%2F%2F100.64.0.10%3A8096
  &name=%E5%AE%B6%E5%BA%AD%20NAS
  &network=tailnet
  &route=direct
  &source=mesharc
```

字段约定：

| 字段 | 值 |
| --- | --- |
| `protocolVersion` | 当前为 `1` |
| `action` | URI 路径中的 `add` 或 `open` |
| `type` | `jellyfin`、`emby`、`plex`、`webdav`、`smb` |
| `url` | 完整 HTTP/HTTPS 服务器地址 |
| `name` | 用户可见的设备或服务器名称 |
| `network` | 固定为 `tailnet` |
| `route` | `direct`、`peerRelay`、`derp`、`unknown`、`unreachable` |
| `source` | 固定为 `mesharc` |

URI 禁止携带用户名、密码、Access Token 和 URL fragment。MeshArc 只负责服务地址
交接，登录与凭据保存仍由 HosPlayer 完成。

正式合作时建议改为 HosPlayer 自有域名下、经过系统验证的 HTTPS App Linking，
MeshArc 继续通过 `UIAbilityContext.openLink()` 调用，不绑定 HosPlayer 的 Ability
名称。

## 服务探测

探测只在用户点击设备卡片中的“检测影音服务”或刷新服务时执行，不做后台全网扫描。
当前检查：

- `8096/tcp`：`/System/Info/Public` 与 `/emby/System/Info/Public`
- `8920/tcp`：相同的 HTTPS 端点，允许媒体服务器常见的自签名证书
- `32400/tcp`：Plex `/identity`

端口开放不会被视为发现成功。Jellyfin 和 Emby 必须返回包含明确 `ProductName`
的公共系统信息；Plex 必须返回带 `machineIdentifier` 和 `version` 的
`MediaContainer`。探测通过 Tailscale 内置 netstack 发起，结果会缓存，且每个设备
只保留同类服务的一个首选地址。

## 无服务器验证

1. 在“设置 > 关于”连续点击应用版本 5 次进入工程模式。
2. 展开“工程诊断”。
3. 点击“运行媒体服务离线自检”。
4. 预期结果：

   ```text
   PASS · 媒体服务识别 4/4 · HosPlayer 参数协议通过
   ```

5. 点击“复制 HosPlayer 参数原型”可检查完整 URI。

离线自检使用内置 Jellyfin、Emby、Plex 和非媒体 HTTP 响应样本，不访问网络。

## 日志

诊断事件只记录动作、结果、服务类型和路径类型，不记录服务器地址、设备名称或凭据。
主要事件包括：

- `media_probe_start` / `media_probe_success` / `media_probe_no_service`
- `media_service_detected`
- `hosplayer_contract_previewed` / `hosplayer_launch_*`
- `media_self_test_started` / `media_self_test_passed` / `media_self_test_failed`

VPN Extension 同时输出不含地址的 HiLog：

```text
Media service probe started
Media service probe completed. available=true|false
```
