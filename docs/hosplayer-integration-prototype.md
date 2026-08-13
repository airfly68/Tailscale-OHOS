# MeshArc × HosPlayer 联动协议

## 当前状态

HosPlayer 已提供服务器导入 Deep Link。MeshArc 在用户从设备卡片选择已识别的媒体服务后，生成导入链接并通过 `UIAbilityContext.openLink()` 拉起 HosPlayer。

MeshArc 只交接媒体服务器的类型、地址和显示名称。用户名、密码、Access Token 以及其他登录凭据仍由 HosPlayer 自行获取和保存。

## URI 约定

```text
hosplayer://server/import
  ?protocolVersion=1
  &type=jellyfin
  &endpoint=http%3A%2F%2F100.64.0.10%3A8096
  &name=%E5%AE%B6%E5%BA%AD%20NAS
```

| 字段 | 约定 |
| --- | --- |
| `protocolVersion` | 当前固定为 `1` |
| `type` | MeshArc 已识别的媒体服务类型，例如 `jellyfin`、`emby` 或 `plex` |
| `endpoint` | 完整的 HTTP/HTTPS 服务器地址，使用 URL 编码 |
| `name` | 用户可见的设备与服务器名称，使用 URL 编码 |

URI 禁止携带用户名、密码、Access Token、URL fragment 或其他凭据。服务器地址必须使用 HTTP/HTTPS、长度不超过 2048 个字符，并且不能包含 userinfo。

调用端使用：

```ets
await context.openLink(uri, { appLinkingOnly: false });
```

`appLinkingOnly: false` 允许系统按 Deep Linking 规则解析 `hosplayer` 自定义 scheme，不绑定 HosPlayer 的 bundleName 或 Ability 名称。

## 服务探测

探测只在用户点击设备卡片中的“检测影音服务”或刷新服务时执行，不做后台全网扫描。当前检查：

- `8096/tcp`：`/System/Info/Public` 与 `/emby/System/Info/Public`
- `8920/tcp`：相同的 HTTPS 端点，允许媒体服务器常见的自签名证书
- `32400/tcp`：Plex `/identity`

端口开放不会被视为发现成功。Jellyfin 和 Emby 必须返回包含明确 `ProductName` 的公共系统信息；Plex 必须返回带 `machineIdentifier` 和 `version` 的 `MediaContainer`。探测通过 Tailscale 内置 netstack 发起，结果会缓存，且每个设备只保留同类服务的一个首选地址。

## 无服务器验证

1. 在“设置 > 关于”连续点击应用版本 5 次进入工程模式。
2. 展开“工程诊断”。
3. 点击“运行媒体服务离线自检”。
4. 预期结果：

   ```text
   PASS · 媒体服务识别 4/4 · HosPlayer 参数协议通过
   ```

5. 点击“复制 HosPlayer 导入链接”可检查完整 URI；其中应包含 `/server/import` 和 `endpoint=`，且不包含凭据。

离线自检使用内置 Jellyfin、Emby、Plex 和非媒体 HTTP 响应样本，不访问网络。

## 日志

诊断事件只记录动作、结果、服务类型和路径类型，不记录服务器地址、设备名称或凭据。主要事件包括：

- `media_probe_start` / `media_probe_success` / `media_probe_no_service`
- `media_service_detected`
- `hosplayer_launch_attempt` / `hosplayer_launch_success` / `hosplayer_launch_failed`
- `media_self_test_started` / `media_self_test_passed` / `media_self_test_failed`

VPN Extension 同时输出不含地址的 HiLog：

```text
Media service probe started
Media service probe completed. available=true|false
```
