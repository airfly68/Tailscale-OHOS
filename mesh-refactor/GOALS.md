# MeshArc 改造目标

## 1. 总 Goal

在保持 MeshArc 当前产品定位、API 23 基线、手机/平板/2in1 设备范围以及现有
业务能力不变的前提下，将工程改造成：

- 单 Entry HAP，并以当前项目选择的最小 Common HAR 建立可验证的契约边界；
  Common HAR 不是最佳实践合规本身，也不要求一次迁移全部 DTO；
- UI、业务状态、平台能力、Native 后端和持久化相互隔离；
- tsnet 设备身份、登录状态和原生持久化格式不变；
- VPN、Tailsend、自定义后端和外部联动协议不变；
- 数据按权威持久数据、应用偏好、日志、IPC、缓存和临时文件分级管理；
- 深浅色资源完整且仅跟随系统；
- 由实际窗口尺寸和内容约束驱动手机、平板、折叠窗口和 2in1 自由窗布局；
  只有问题证据成立时才增加高宽比策略；
- 每个 Milestone 均能独立构建、测试、验收和回退；
- 异步任务、监听器、定时器、文件 watcher 和 Ability/页面生命周期具有明确
  所有者、取消规则和过期结果防护，不因拆分改变现有启动、恢复或后台语义。

## 2. 必须保持的兼容边界

- bundleName：`io.github.tailscaleohos`。
- Ability 名称和类型：
  - `EntryAbility`；
  - `TailscaleVpnExtensionAbility`。
- 页面入口：`pages/Index`。
- 通知 Want 参数：
  - `taildropOpenInbox`；
  - `taildropNotificationAction`；
  - `taildropNotificationFileName`；
  - `taildropNotificationFileSize`。
- Moonlight Want 和 HosPlayer URI 参数。
- `libtailscale_ohos` 的 ArkTS 声明、NAPI 方法和 Go C ABI。
- VPN 配置字符串、VPN/Tailsend 文件名、JSON 字段和请求状态语义。
- tsnet 状态路径体系、文件格式、原子写入、锁和崩溃恢复语义。
- 控制服务器、网络偏好、出口节点、Tailsend 历史和布局偏好的已有字段。
- 已有用户数据、设备身份和登录状态。

## 3. 可独立执行的子 Goal

### G1：规则和回归基线

恢复规则索引和冲突记录并核验来源、级别和适用条件；建立兼容契约 fixture、
ArkTS/Go 统一测试入口、状态/生命周期基线和 `STATUS.md`。在规则核验完成前，
不得开始修改生产代码的 Milestone。

### G2：公共契约模块

以最小 Common HAR 建立纯契约边界，先通过兼容适配器接入，不一次性替换全部
DTO。Common HAR 不得依赖 Entry，也不得引入 ArkUI 状态装饰器、Context、I/O
或生命周期副作用。

### G3：安全数据边界

验证并保持应用私有 EL2，列出所有数据位置和用途，区分权威数据、日志、IPC、
缓存和临时文件；已正确位于 EL2 时只建立断言，不移动或改写 tsnet 状态。

### G4：Home/VPN 边界

按一次一个行为切片，将连接、登录、出口节点、流量、peer 和 VPN 生命周期从
页面组件抽离到最少的可测试边界，并保持现有 VPN 行为。Gateway、Coordinator、
Repository 和 ViewModel 只是候选命名，不是必须同时引入的标准实现。

### G5：Tailsend 边界

按发送、接收/通知、历史/缓存三个行为切片逐步抽离 picker、文件准备、发送、
接收、通知、预览、历史、缓存和恢复；保留用户交互所需的 UIContext 边界，
保持请求协议、并发顺序、取消语义、删除时机和用户操作不变。

### G6：Settings 与 AppShell 边界

将 Settings、Account、Diagnostics、自定义后端和应用壳拆分；AppShell 只负责
Tab、Feature 生命周期和外部 Want 转换。

### G7：主题和资源

优先治理实际重复或影响可读性的语义颜色和用户可见文案；仅在有多个消费者时
建立字号、间距、圆角、动效和材质 Token，不做机械式全量 Token 化。
base/dark 与 base/zh_CN 资源保持同名完整，主题只跟随系统。

### G8：窗口和多设备布局

先建立只观测不改变业务的 WindowEnvironment，再依据可复现布局问题选择最少的
横向/纵向或高宽比策略。候选断点不是标准要求；分屏、自由窗、安全区和阅读
焦点连续性按实际目标设备与窗口条件验收。

### G9：系统能力与交付收口

审计要求能力集、联想能力集和权限，只为实际使用的可选 API 增加 `canIUse()`
或 API 23 规定的等价降级，并完成升级、恢复、VPN、Tailsend、主题和窗口全回归。

## 4. 总体验收条件

- `BridgeStatus.ets` 的职责逐步减少；是否删除文件不是验收目标。只有全部调用方、
  生命周期和回归证据完成后，才可在独立清理 Milestone 删除兼容外壳。
- ArkUI 页面不得直接调用 Native、VPN Extension 或 `fileIo`。
- 工程依赖为 Entry -> Common HAR，Common HAR 不得反向依赖 Entry。
- 安装升级后设备身份和登录状态不变。
- VPN 连接、断开、重连、系统终止和设备重启恢复正常。
- Tailsend 发送、接收、取消、重试、通知入口和导出正常。
- HTTP 自定义后端继续可用，但新增明确风险提示和二次确认。
- 缓存清理不得删除 tsnet 状态；临时数据丢失不得造成远端文件误删。
- 诊断包和日志不包含凭据、私钥、密码、完整授权 URL 或敏感请求参数。
- 浅色、深色和运行时切换无不可读内容。
- 每个实际采用的断点都具备边界两侧的确定性策略测试；未采用的候选阈值不形成
  虚假验收。
- 手机竖/横屏、平板全屏/分屏和 2in1 自由窗按可获得设备验证；折叠开合仅在
  有对应真机/模拟器时作为设备验收，否则用窗口尺寸变化验证通用连续性并记录
  未验证条件。
- 重复进入/退出页面、前后台切换、冷/热启动和通知重入不会重复注册监听、重复
  发起 VPN/Tailsend 动作、应用过期 Promise 结果或泄漏资源。
- 每个 Milestone 的回退不依赖删除新数据、恢复旧明文、重新登录或重新生成设备
  身份；涉及位置变更时，旧数据至少保留到独立清理决策之后。
- 每个 Milestone 完成后检查 diff、执行测试和构建，并更新
  `mesh-refactor/STATUS.md`。

## 5. 总 Non-goals

- 不升级 API 24、Tailscale、Go 或 Hvigor。
- 不新增 wearable、车机、TV 或独立 PC HAP。
- 不建立 Feature HAR、HSP 或按需加载模块。
- 不新增主题手动开关。
- 不新增应用内深链、内部主动分屏、折叠悬停专用功能或大屏独占业务。
- 不重写 tsnet 持久化协议，不全量 HUKS，不自行解析其内部状态。
- 不因安全改造强制重新登录或生成新设备身份。
- 不禁止现有 HTTP Headscale。
- 不申请 LiveView、自动启动或其他新系统特权。
- 不在正常测试迭代中进行完整视觉截图审查，除非用户明确要求。
