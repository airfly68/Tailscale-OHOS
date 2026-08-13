# MeshArc 改造决策记录

## D001：物理模块结构

- **状态：** 已确认
- **决定：** 保留单 Entry HAP，新增单 Common HAR。
- **范围：** Common HAR 只承载纯 DTO、序列化、验证、错误类型和无 Entry
  副作用的公共能力。
- **约束：** 这是基于当前工程耦合的项目架构选择，不是把推荐项或示例模块
  形态升级为强制规范。先建立最小模块和兼容适配器，再由各 Feature Milestone
  逐步采用；不得为了“完成 Common HAR”一次替换全部 DTO。
- **理由：** 当前只有一个 UIAbility，VPN Extension 是核心能力并与 Native、
  后端恢复和同沙箱 IPC 强耦合。Common HAR 可以建立编译期单向边界，同时避免
  多 Feature HAR/HSP 的部署和构建成本。
- **排除：** 不建立 Feature HAR、HSP、公共 HSP 壳或按需加载模块。

## D002：VPN Extension 和 Native 所属模块

- **状态：** 已确认
- **决定：** `TailscaleVpnExtensionAbility`、C++ Node-API 和 Go c-shared 库
  继续留在 Entry。
- **理由：** 保持 Ability 名称、Native 加载、文件 IPC、沙箱路径和已验证恢复
  流程不变。

## D003：SDK 基线

- **状态：** 已确认
- **决定：** 本轮保持 HarmonyOS API 23。
- **理由：** API 23 是当前已验证基线，V2 状态管理和 HDS 材质已可用。
- **排除：** API 24 升级必须另立计划，不能混入任何 Milestone。

## D004：设备范围

- **状态：** 已确认
- **决定：** 继续支持 phone、tablet、2in1；折叠屏按手机/平板窗口形态覆盖。
- **排除：** wearable、圆屏、小方形屏、车机、TV 和独立 PC 产品 HAP。

## D005：主题行为

- **状态：** 已确认
- **决定：** 主题只跟随系统颜色模式。
- **理由：** 保持现有产品行为，使用 base/dark 资源和系统 Token 完成适配。
- **排除：** 不新增“跟随系统/浅色/深色”手动开关或新的持久化主题字段。

## D006：自定义 HTTP 后端

- **状态：** 已确认
- **决定：** 保留 HTTP Headscale 兼容；保存新的 HTTP 地址时显示独立风险说明
  并要求二次确认。
- **兼容要求：**
  - 已有 HTTP 配置继续读取；
  - 不静默改成 HTTPS；
  - 不修改控制服务器字段或状态目录哈希规则；
  - 默认地址继续为 Tailscale 官方 HTTPS 控制面。
- **冲突处理：** 这是对“优先 HTTPS”安全规则的明确产品兼容例外，必须在
  安全审计和 UI 中可见。

## D007：tsnet 持久状态保护

- **状态：** 已确认
- **决定：** 验证并保持应用私有 EL2，保留 tsnet 原路径、文件名、格式、读写、
  原子更新、锁和崩溃恢复语义。当前上下文已正确时只建立断言；只有 API 23 和
  设备证据证明需要时才增加显式设置。
- **禁止：**
  - 不直接对完整 tsnet 状态增加透明 HUKS 层；
  - 不自行解析或重组内部状态；
  - 不因迁移失败删除状态、生成新身份或强制重新登录；
  - 如果当前已位于正确 EL2，不为体现改造而重复搬迁。

## D008：选择性秘密存储

- **状态：** 已确认
- **决定：** 仅保护 MeshArc 自己管理、可独立识别的小型秘密。
- **优先级：**
  1. 密码、Token、API Key 等小型凭据优先评估 Asset Store Kit；
  2. 需要生成、保存或使用密码学密钥时使用 HUKS；
  3. 页面偏好、普通配置、大文件、缓存、日志和完整 tsnet 状态不进入 HUKS。
- **当前结论：** 当前控制服务器配置只有 URL，没有应用自有秘密，不创建无
  消费者的 Asset Store/HUKS 数据。
- **失败规则：** 读取失败不得静默生成新凭据、覆盖旧数据或退回明文存储。

## D009：日志、诊断和临时文件

- **状态：** 已确认
- **决定：**
  - 日志不得记录 Token、私钥、密码、完整授权 URL、敏感查询参数、请求头或
    完整 tsnet 状态；
  - 节点名、IP 和后端地址按排障价值分类保留，避免过度删除；
  - 确认可再生成或已具备恢复协议的临时文件和导出中间文件进入 cache/temp；
  - 导出成功、失败或取消都清理中间文件；
  - 用户主动导出的诊断包必须先脱敏；
  - 日志和临时文件同时设置数量、时间或容量上限。

## D010：数据迁移策略

- **状态：** 已确认
- **决定：** 只有确实需要变更位置的数据才迁移；迁移必须幂等，并在可回退
  窗口内保留旧数据和旧读取路径。权威用户数据默认不迁移。
- **顺序：**
  1. 检查目标是否已有有效数据；
  2. 复制到目标同目录临时文件；
  3. 校验完整性；
  4. 原子替换；
  5. 读回验证；
  6. 在克隆 fixture/测试沙箱执行“旧版 -> 新版 -> 旧版 -> 新版”往返；
  7. 任何失败继续以旧数据为权威并回退；
  8. 崩溃后可重复执行；
  9. 迁移 Milestone 不删除旧数据，删除只能进入独立清理 Milestone，并在确认
     回退窗口结束、旧版本不再需要读取后执行。
- **格式要求：** 不修改已有配置字段和状态格式；新增元数据必须向后兼容。
- **写入兼容：** 在旧版本仍可能回退的期间，不允许只写旧版本无法读取的新
  位置或新格式；需要持久恢复的状态必须保持旧位置为权威或实施可验证双写。

## D011：状态管理技术选择

- **状态：** 已确认
- **决定：** 新的 UI-facing Feature 状态可优先小范围使用 API 23 已稳定的
  `@ObservedV2/@Trace`；是否使用装饰器由该切片的最小实现决定，不把现有 V1
  状态做全量迁移。纯领域状态、Common HAR DTO 和持久化模型不依赖 ArkUI
  状态装饰器。
- **保留：** 外部 Want 使用的现有 AppStorage 键保持兼容，可由适配器转换为
  Feature 动作。
- **排除：** 不把高频业务状态继续扩大到全局 AppStorage。
- **所有权：** 每个 Feature 必须记录状态唯一所有者、写入入口、UI 线程更新
  边界、并发请求代次/取消策略和销毁后的过期结果处理；技术选型不能改变状态
  顺序、默认值或错误可见性。

## D012：响应式断点和导航

- **状态：** 已确认（Home M12A，2026-08-01）
- **已确认原则：** 使用窗口而非设备型号；优先以内容最小宽高、可操作性和
  现有 600/840vp 行为为依据，不按设备型号分支。
- **候选策略（不是最佳实践标准值）：**
  - xs：`<320vp`；
  - sm：`320-599vp`；
  - md：`600-839vp`；
  - lg：`840-1439vp`；
  - xl：`>=1440vp`；
  - 纵向 sm：高宽比 `<0.8`；md：`0.8-1.19`；lg：`>=1.2`。
- **导航：**
  - `<600vp` 使用底部导航；
  - 600-839vp 的高/竖窗口使用底部导航，横向或方形窗口使用侧导航；
  - `>=840vp` 使用侧导航和按页面需要的主从布局；
  - `>=1440vp` 提高信息密度并约束内容宽度，不增加新业务。
- **冲突处理：** 保留现有已验证的 600/840vp 行为作为基线；候选边界只用于
  验证当前策略是否遗漏窄窗、超宽窗或大屏竖向场景。
- **核验要求：** 320/1440vp 和 0.8/1.2 只能在内容约束测试与目标窗口矩阵
  证明需要后纳入实现。未采用的候选阈值不得写入生产代码或验收脚本。
- **M12A 核验结果：** Home 在 600/840vp 两侧保持可操作的单栏/主从策略；
  600-839vp 的竖向窗口保留底部导航，横向或方形窗口使用侧导航；320/1440vp
  与 0.8/1.2 未形成额外生产断点。后续 Transfer、Settings 和跨页 Shell 仍需各自
  重新验证，不因本次 Home 确认而自动采用。

## D013：窗口与沉浸式

- **状态：** 待设备核验
- **决定：** 目标行为是尊重系统旋转锁，并在全屏、分屏和自由窗口下按实际
  窗口布局。先验证当前 API 23 配置和目标设备行为；只有缺少该声明确实导致
  行为问题且回归通过时，才配置 `FOLLOW_DESKTOP`。配置字面值不是验收目标。
- **沉浸式：** 统一 AppShell 可以保留 edge-to-edge；页面内容由 HDS 安全区
  和统一 WindowEnvironment 处理避让。
- **排除：** 不隐藏自由窗口标题栏，不定制三键区，不主动创建应用内分屏。

## D014：折叠连续性

- **状态：** 部分确认
- **决定：** 页面布局只由窗口尺寸和断点驱动，不用 foldStatus 直接切布局。
- **保持状态：** 当前 Tab、选中 peer、未提交的 Transfer 用户输入/接收状态、
  发生布局重建的 List/Scroll 阅读锚点和 Settings 滚动位置。不得通过强行恢复
  过期组件引用、重复请求或重复远端删除来保持状态。
- **待确认：** Sheet/Dialog 等瞬态覆盖层在布局类别变化时，是关闭但保留底层
  输入，还是在重建后恢复展示。默认不把“必须恢复覆盖层”作为验收条件。
- **排除：** 不实现悬停态专属业务。

## D015：版本、构建与发布

- **状态：** 已确认
- **决定：** 每个 Milestone 使用仓库已有签名和 HDC 工作流构建测试 HAP。
- **版本：** 本地构建不消耗 `versionCode`；只有实际上传的新包才按仓库规则取
  所有已用版本中的最大值加 1。
- **发布：** Production Release 编译前必须先通知用户并等待是否进行完整发布
  审查的决定。

## D016：文档缺失处理

- **状态：** 实施门禁
- **决定：** `RULE_INDEX.md` 和 `RULE_CONFLICTS.md` 缺失，不阻止计划审查；
  Milestone 0 只依据现有 extracted/rules 重建，不读取原始 HTML。两个文件未
  恢复并完成级别、来源、适用条件和冲突核验前，不得开始修改生产代码的
  Milestone。

## D017：生命周期与异步完成语义

- **状态：** 已确认
- **决定：** UI 可见性、Feature 生命周期、UIAbility 前后台和 VPN 后台生命
  周期分别建模，Tab 切换或页面 `aboutToDisappear()` 不得自动停止核心 VPN
  后端或取消需要继续的跨进程操作。
- **约束：** 定时器、文件 watcher、Window/Ability 监听和 Native Promise 均有
  唯一所有者；注册/注销使用同一回调引用；重复进入幂等；销毁后异步结果通过
  generation/token 或等价机制失效；UI 状态只在有效 UI 生命周期和正确线程
  更新。
- **验证：** 冷/热启动、`onNewWant`、前后台切换、Tab 切换、系统终止恢复和
  通知重入均需有可重复测试或真机证据。

## D018：兼容外壳与回退窗口

- **状态：** 已确认
- **决定：** 新边界先以适配器或兼容外壳接入，旧实现的删除与新实现切换不在
  同一个 Milestone。`BridgeStatus.ets` 的删除只进入独立清理 Milestone，且不以
  文件行数或文件消失作为架构验收。
- **回退证据：** 每个 Milestone 必须记录代码回退点、数据兼容条件和未完成
  清理；涉及持久数据时，在克隆 fixture/测试沙箱完成前后版本往返验证。

## 尚待确认事项

1. 是否采用 D012 的 320/1440vp 和 0.8/1.2 候选阈值，还是只保留现有
   600/840vp 并按实际内容约束逐页增加阈值。
2. 布局类别变化时，Sheet/Dialog 等瞬态覆盖层应关闭并保留底层输入，还是恢复
   展示。

在这两项确认前，可以完成 Milestone 0-11 中不依赖该选择的工作，但不得开始
对应的响应式切换和覆盖层连续性实现。

## D012/D014 M12B Transfer independent verification (2026-08-01)

- D012 is independently confirmed for Transfer: the content strategy has one
  adopted `840vp` boundary only. Below it, Transfer is single-column; at or
  above it, targets and activity are split. The `600vp` Shell navigation rule
  remains outside this Transfer strategy, and `1440vp`, device-type, and
  fold-state branches are not production inputs.
- D014 is independently verified for the Transfer scope: `BridgeStatus` keeps
  unsubmitted text, receive state, send progress, cancellation state, picker
  ownership, and notification/remote-delete claims. The shared Scroll anchor
  is restored with one lifecycle-scoped task after a layout rebuild. A pending
  cancellation returns idempotently, and layout changes do not schedule
  network, file, picker, save, send, or delete work. Transient picker/dialog
  component references are intentionally not restored.
- The fixture covers `839→840→839`, `600vp` single-column continuity,
  `840/1439/1440vp` split continuity, retained state, and one-shot action
  claims. Phone evidence confirms the below-840 branch; tablet and 2in1
  evidence is **not executed** because those targets are unavailable.

## D012/D014 M12C Settings independent verification (2026-08-01)

- D012 is independently confirmed for Settings/Account/Diagnostics: the
  adopted content strategy has one `840vp` boundary only. Below it the
  controlled Settings content is single-column; at or above it the sections
  are two-column. The `600vp` Shell navigation rule and the M12B Transfer
  strategy are not reused as Settings state or device branches.
- D014 is verified for the Settings scope within the confirmed boundary:
  `BridgeStatus` retains Preferences, Account, cache, Diagnostics disclosure,
  and report state; the shared Settings Scroll anchor is restored with one
  lifecycle-scoped task. Resize does not submit unconfirmed settings, reload
  Preferences, duplicate observer registration/unregistration, or generate a
  diagnostic report. Transient Sheet/Dialog/Alert references are **not
  restored** because that overlay policy remains unconfirmed.
- The M12C fixture covers `599/600/839/840/1439/1440vp`, `839↔840↔839`
  continuity, retained state, request guards, and forbidden resize work. The
  final phone UI probe is **not executed** because the only connected phone was
  system-locked; tablet and 2in1 targets are also **not executed**.

## D013/D014 M12D Shell window continuity independent verification (2026-08-01)

- D013 is independently verified for the Shell boundary: the window-level
  policy keeps edge-to-edge and visible system bars in `EntryAbility`,
  `WindowEnvironment` remains the only owner of window-size/avoid-area/density
  listeners, HDS `titleBar` owns page content safe-area avoidance, and the
  freeform system title area remains visible. No `FOLLOW_DESKTOP` or hidden
  window-decor strategy was introduced.
- D014 is preserved rather than expanded: the stable
  `Index → AppShell → BridgeStatus` host keeps Tab, peer, Transfer, Settings
  and Scroll state across the existing area-change/layout path. The path does
  not restore Sheet/Dialog/Alert references; those transient overlays remain
  not restored until their policy is separately confirmed.
- The M12D fixture covers phone landscape, tablet fullscreen/split-screen,
  2in1 free-window and the fold-open/close equivalent window-size change
  cases. The foldable device itself is **not verified**; tablet, 2in1 and
  foldable evidence are **not executed** in the current environment.
