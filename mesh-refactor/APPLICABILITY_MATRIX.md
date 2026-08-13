# MeshArc 最佳实践适用性矩阵

## 1. 判定说明

- **符合**：当前已有可验证实现。
- **部分符合**：方向正确，但边界、覆盖或测试不足。
- **不符合**：规则适用，当前没有相应实现。
- **不适用**：当前产品范围或组件不满足适用条件。
- **条件性**：仅在后续选择对应 API、组件或能力时生效。

规则级别按 B01-B05 已提取规则记录。Milestone 0 已于 2026-08-01 对 105 条
结论逐项复核：来源、级别、适用条件和冲突处置见 `RULE_INDEX.md` 与
`RULE_CONFLICTS.md`。本表仍不能单独证明某项是强制实现任务；`RECOMMENDED`、
`OPTIONAL` 和 `EXAMPLE` 只用于方案权衡，实现名称、模块形态和示例阈值也不作为
验收条件。

## 2. B01：多端产品与体验基线

| 规则 | 级别 | 适用性 | 当前状态 | 审查结论 |
| --- | --- | --- | --- | --- |
| B01-R001 | RECOMMENDED | 高 | 部分符合 | 已声明多端并有响应式基础，缺少统一多设备规划和验收矩阵。 |
| B01-R002 | RECOMMENDED | 高 | 部分符合 | 有一致导航和视觉基础，差异性、灵活性和兼容性尚未系统验证。 |
| B01-R003 | RECOMMENDED | 高 | 部分符合 | 可随宽度变化；方向、纵向策略和折叠连续性只在目标窗口出现可复现问题时补充。 |
| B01-R004 | RECOMMENDED | 高 | 部分符合 | 已有 components/services，巨型组件仍造成严重耦合。 |
| B01-R005 | REQUIRED | 高 | 部分符合 | 设备类型已声明，SysCap 要求能力集尚未审计。 |
| B01-R006 | RECOMMENDED | 高 | 不符合 | 实际使用的可选系统能力尚未逐调用边界核对能力检查和降级；不要求无消费者的统一包装。 |
| B01-R007 | RECOMMENDED | 高 | 符合 | 使用 ArkTS 声明式 ArkUI。 |
| B01-R008 | RECOMMENDED | 高 | 符合 | manifest 已包含 phone、tablet、2in1。 |
| B01-R009 | RECOMMENDED | 中 | 部分符合 | 有真机 UI probe，无 Multi-profile 或等价窗口矩阵自动检查。 |
| B01-R010 | RECOMMENDED | 高 | 部分符合 | 已有 600/840vp；xs、xl 和高宽比属于待内容约束验证的候选策略。 |
| B01-R011 | EXAMPLE | 低 | 不适用 | 天气应用的大屏内容超集不是 MeshArc 通用要求。 |
| B01-R012 | EXAMPLE | 低 | 不适用 | 示例组件组合不作为 MeshArc 固定实现。 |

## 3. B02：应用架构与数据安全边界

| 规则 | 级别 | 适用性 | 当前状态 | 审查结论 |
| --- | --- | --- | --- | --- |
| B02-R001 | RECOMMENDED | 高 | 部分符合 | 有初步目录分工，但层间和模块间依赖未受约束。 |
| B02-R002 | RECOMMENDED | 高 | 部分符合 | 职责和依赖边界仍不清晰；不要求机械复制固定三层拓扑。 |
| B02-R003 | REQUIRED | 高 | 符合 | M1 已注册最小 Common HAR；`M1Common` 静态 suite 断言 Entry→Common、拒绝 Common→Entry 反向样例，且 HAR 可独立构建。 |
| B02-R004 | REQUIRED | 高 | 部分符合 | M1 仅迁移了多消费者的纯连接路径 DTO，并保留 Entry 兼容适配器；其余 DTO、文件协议和副作用留待后续行为切片。 |
| B02-R005 | RECOMMENDED | 高 | 符合 | D001 记录单 Entry HAP + 最小 Common HAR 的选型；未建立 Feature HAR/HSP，VPN Extension、C++ 和 Go 仍在 Entry。 |
| B02-R006 | RECOMMENDED | 高 | 部分符合 | 已有 UIAbility 和 VPN Extension，缺少任务/窗口形态 ADR。 |
| B02-R007 | RECOMMENDED | 条件性 | 不适用 | 规则条件要求无需 ExtensionAbility，MeshArc 不满足。 |
| B02-R008 | REQUIRED | 条件性 | 不适用 | 没有需要独立安装运行的模块。 |
| B02-R009 | RECOMMENDED | 条件性 | 不适用 | VPN Extension 是核心能力且与 Native、状态恢复强耦合，不作为独立扩展特性拆分。 |
| B02-R010 | REQUIRED | 条件性 | 不适用 | Common HAR 暂不跨独立应用发布。 |
| B02-R011 | RECOMMENDED | 条件性 | 不适用 | 不采用低频 HSP 按需加载。 |
| B02-R012 | RECOMMENDED | 条件性 | 不适用 | 工程无 HSP。 |
| B02-R013 | RECOMMENDED | 条件性 | 不适用 | 工程无公共 HSP 模块壳。 |
| B02-R014 | REQUIRED | 条件性 | 不适用 | 工程无跨应用 HAR 依赖 HSP。 |
| B02-R015 | REQUIRED | 高 | 符合 | M2 `DATA_INVENTORY.md` 覆盖权威 tsnet 状态、控制服务器、登录、偏好、日志、VPN IPC、Tailsend、历史、诊断、缓存和临时文件，并为每项记录唯一所有者、权限、恢复与删除规则。 |
| B02-R016 | REQUIRED | 条件性 | 不适用 | 不使用 HarmonyOS 分布式数据等级同步。 |
| B02-R017 | REQUIRED | 条件性 | 不适用 | Tailscale/Tailsend 网络传输不属于系统分布式数据同步。 |
| B02-R018 | RECOMMENDED | 高 | 符合 | M2 的 `StoragePaths` 原样返回平台 `filesDir`，fixture 与 VPN data/exit-node probe 固化 EL2 路径；出口节点选择写入会在启动 VPN 前串行完成并立即重读，避免切换后端时丢失选择，名称仅使用 `HostName` 而非 MagicDNS `DNSName`。最新 HAP 覆盖安装、VPN data 和 exit-node 数据面 probe 均已通过；未添加重复 EL2 初始化。 |
| B02-R019 | REQUIRED | 条件性 | 不适用 | 当前没有 HUKS 加解密；未来使用时必须严格匹配算法参数。 |
| B02-R020 | EXAMPLE | 低 | 不适用 | 健康数据二次加密案例不升级为全量文件加密规范。 |
| B02-R021 | REQUIRED | 高 | 部分符合 | M2 将数据分类、所有者、删除权限、恢复规则和无迁移边界固定为清单与静态 suite；持续审计、故障注入和未来迁移恢复仍由后续行为 Milestone 验收。 |
| B02-R022 | RECOMMENDED | 高 | 部分符合 | M2 维持现有 EL2、TLS、沙箱与脱敏策略，未将健康数据案例升级为全量 HUKS；HTTP 兼容例外仍需风险确认和记录。 |

## 4. B03：多设备窗口环境

| 规则 | 级别 | 适用性 | 当前状态 | 审查结论 |
| --- | --- | --- | --- | --- |
| B03-R001 | RECOMMENDED | 高 | 部分符合 | 未明确记录窗口旋转策略；先验证当前 API 23 和目标设备行为，不以配置 `FOLLOW_DESKTOP` 作为硬性验收。 |
| B03-R002 | RECOMMENDED | 高 | 符合 | 未使用绕过控制中心旋转锁的自动旋转策略。 |
| B03-R003 | OPTIONAL | 高 | 条件性 | 仅当当前方向行为不满足产品目标且 API 23/目标设备验证通过时考虑配置 FOLLOW_DESKTOP。 |
| B03-R004 | REQUIRED | 高 | 符合 | 未错误地用 `display.Orientation` 设置窗口方向。 |
| B03-R005 | REQUIRED | 条件性 | 不适用 | 当前不依赖 orientation 与 rotation 映射。 |
| B03-R006 | RECOMMENDED | 条件性 | 不适用 | 没有依赖 180 度旋转的方向专属业务逻辑。 |
| B03-R007 | RECOMMENDED | 高 | 符合 | EntryAbility 使用 `getMainWindowSync()`。 |
| B03-R008 | OPTIONAL | 高 | 符合 | 未限制时平台默认支持全屏、分屏、自由窗口；仅在设备证据显示需要时增加声明。 |
| B03-R009 | RECOMMENDED | 高 | 部分符合 | 布局随面积变化，但没有统一窗口模式/尺寸环境。 |
| B03-R010 | REQUIRED | 条件性 | 不适用 | 当前未在 windowStatusChange 中读取窗口尺寸。 |
| B03-R011 | RECOMMENDED | 条件性 | 不适用 | 页面未在 aboutToAppear 读取 `windowRect`。 |
| B03-R012 | RECOMMENDED | 高 | 部分符合 | 当前 `onAreaChange` 可驱动宽度布局；仅在需要窗口级尺寸、安全区或 density 时引入集中监听。 |
| B03-R013 | RECOMMENDED | 高 | 条件性 | 新增监听时必须只处理本回调数据，且不得执行 I/O。 |
| B03-R014 | REQUIRED | 高 | 部分符合 | 能缩放，但缺少平台分屏比例矩阵和边界测试。 |
| B03-R015 | EXAMPLE | 低 | 不适用 | 不主动创建应用内左右分屏。 |
| B03-R016 | RECOMMENDED | 高 | 部分符合 | 没有强制 2in1 全屏，但尚未验证默认自由窗口行为。 |
| B03-R017 | RECOMMENDED | 高 | 部分符合 | 使用全局 edge-to-edge，页面由 HDS 部分处理避让；需明确统一策略。 |
| B03-R018 | OPTIONAL | 条件性 | 不适用 | 当前没有直接以 `background()` 实现该类沉浸。 |
| B03-R019 | REQUIRED | 条件性 | 不适用 | 当前未使用 `ignoreLayoutSafeArea()` 扩展内容。 |
| B03-R020 | REQUIRED | 条件性 | 不适用 | 当前未使用 `expandSafeArea`。 |
| B03-R021 | REQUIRED | 高 | 部分符合 | 全局全屏已启用，HDS 安全区存在，但缺少逐页和自由窗验证。 |
| B03-R022 | RECOMMENDED | 高 | 部分符合 | 主要依赖 HDS 安全区，未建立统一 avoidAreaChange 模型。 |
| B03-R023 | REQUIRED | 条件性 | 不适用 | 不做自由窗口标题栏自定义沉浸。 |
| B03-R024 | RECOMMENDED | 高 | 部分符合 | 当前仍是窗口级方案；后续由 Shell 和页面组件明确职责。 |
| B03-R025 | EXAMPLE | 低 | 不适用 | 不隐藏系统栏实施定制挖孔避让。 |
| B03-R026 | EXAMPLE | 低 | 不适用 | 不隐藏自由窗标题栏或定制三键区。 |

## 5. B04：响应式界面布局

| 规则 | 级别 | 适用性 | 当前状态 | 审查结论 |
| --- | --- | --- | --- | --- |
| B04-R001 | RECOMMENDED | 高 | 部分符合 | 有 Row/Column/Grid 和断点策略，但布局规则分散在巨型组件。 |
| B04-R002 | RECOMMENDED | 高 | 部分符合 | 当前只使用横向宽度；先验证宽矮/窄高窗口是否出现内容问题，再决定是否增加高宽比。 |
| B04-R003 | RECOMMENDED | 高 | 部分符合 | 仅落实 600/840vp；320/1440vp 和纵向阈值只能作为待验证候选，不能因示例出现而强制补齐。 |
| B04-R004 | RECOMMENDED | 高 | 符合 | 当前按窗口内容宽度而非设备型号切换。 |
| B04-R005 | OPTIONAL | 中 | 条件性 | 选择集中 WindowEnvironment 主动监听，不强制迁移到 `@Env`。 |
| B04-R006 | RECOMMENDED | 高 | 部分符合 | 需要验证窄高、宽矮等窗口内容是否失效；只有出现可复现问题时才增加纵向或高宽比策略。 |
| B04-R007 | OPTIONAL | 中 | 部分符合 | vp 会随布局变化，但没有 densityUpdate 行为和测试。 |
| B04-R008 | OPTIONAL | 高 | 符合 | 已采用单栏、双栏、主从和导航挪移。 |
| B04-R009 | REQUIRED | 高 | 符合 | `GridRow` 均与 `GridCol` 配对。 |
| B04-R010 | RECOMMENDED | 条件性 | 不适用 | 当前重复列表无需随宽度增加 lanes；若后续采用则按规则实现。 |
| B04-R011 | RECOMMENDED | 条件性 | 不适用 | 未使用 WaterFlow。 |
| B04-R012 | RECOMMENDED | 高 | 部分符合 | 有侧导航和部分主从布局，尚未统一到窗口策略。 |
| B04-R013 | RECOMMENDED | 高 | 符合 | HdsTabs 已实现底部/侧边导航切换。 |
| B04-R014 | RECOMMENDED | 高 | 部分符合 | 超宽窗口已有最大宽度约束；是否需要 xl 类别由内容密度问题决定，不要求专用业务布局。 |
| B04-R015 | RECOMMENDED | 高 | 部分符合 | 宽屏已有侧导航和部分双栏，需逐页验证而非强制统一布局。 |
| B04-R016 | RECOMMENDED | 高 | 部分符合 | 大屏竖向的导航可用性尚未验证；只有出现问题时才增加纵向分支。 |
| B04-R017 | RECOMMENDED | 高 | 部分符合 | 窄屏已有单栏和底部导航，仍有固定尺寸和状态集中问题。 |
| B04-R018 | RECOMMENDED | 低 | 不适用 | 不支持 wearable/圆屏 HAP。 |
| B04-R019 | RECOMMENDED | 低 | 不适用 | 不开发圆屏弧形 UI。 |
| B04-R020 | REQUIRED | 低 | 不适用 | 未使用 ArcListItem。 |
| B04-R021 | EXAMPLE | 低 | 不适用 | 小方形屏弹窗案例不适用于当前设备范围。 |
| B04-R022 | EXAMPLE | 低 | 不适用 | 圆形表盘案例不适用。 |

## 6. B05：设备能力、设置与视觉适配

| 规则 | 级别 | 适用性 | 当前状态 | 审查结论 |
| --- | --- | --- | --- | --- |
| B05-R001 | REQUIRED | 高 | 部分符合 | deviceTypes 已声明，要求能力集尚未审计。 |
| B05-R002 | REQUIRED | 高 | 不符合 | 核心 VPN/网络能力尚未形成显式要求能力集清单。 |
| B05-R003 | REQUIRED | 高 | 不符合 | 实际使用且非要求能力集的可选 API 尚未逐调用点核对 `canIUse()` 或等价机制。 |
| B05-R004 | RECOMMENDED | 高 | 不符合 | 没有要求/联想能力集的变更审查机制。 |
| B05-R005 | RECOMMENDED | 高 | 部分符合 | 已按窗口宽度适配，缺少分屏/自由窗矩阵；纵向断点只在问题证据成立时增加。 |
| B05-R006 | RECOMMENDED | 条件性 | 不适用 | 没有视频播放器页面。 |
| B05-R007 | REQUIRED | 条件性 | 不适用 | 不存在视频内容区域随窗口重算的业务。 |
| B05-R008 | REQUIRED | 高 | 部分符合 | 单组件可保留多数状态，但布局类别变化时的连续性尚未验收；折叠设备条件需单独记录。 |
| B05-R009 | RECOMMENDED | 高 | 部分符合 | 未错误使用 foldStatus 驱动布局；是否统一 windowSizeChange 取决于窗口环境消费者。 |
| B05-R010 | REQUIRED | 高 | 部分符合 | 仅对布局类别变化时会重建或重排的 List/Scroll 验证阅读焦点；不要求所有列表机械保存索引。规则条件待核验。 |
| B05-R011 | REQUIRED | 条件性 | 不适用 | 未使用 WaterFlow。 |
| B05-R012 | REQUIRED | 条件性 | 不适用 | 不支持悬停态专属业务。 |
| B05-R013 | RECOMMENDED | 高 | 部分符合 | M1 已为一个多消费者纯 DTO 切片建立可验证的 Entry→Common 边界；其他 Feature 的职责边界仍留待各自 Milestone。 |
| B05-R014 | EXAMPLE | 低 | 不适用 | 已决定不建立独立 PC 产品包。 |
| B05-R015 | EXAMPLE | 中 | 条件性 | 仅用于帮助设计测试场景，不要求复制其 HDS、监听器、断点或页面组合。 |
| B05-R016 | EXAMPLE | 低 | 不适用 | HdsNavigation 路由表只是案例；MeshArc 保持单入口 Tabs。 |
| B05-R017 | REQUIRED | 高 | 部分符合 | 有深色资源和系统栏适配，硬编码颜色和文案仍影响一致性。 |
| B05-R018 | REQUIRED | 高 | 部分符合 | 已有 base/dark 同名颜色，但并非所有定制色均资源化。 |
| B05-R019 | OPTIONAL | 高 | 符合 | 当前跟随系统，已确认不新增手动主题开关。 |
| B05-R020 | RECOMMENDED | 高 | 部分符合 | 大部分使用系统 Token，部分组件仍硬编码定制色。 |
| B05-R021 | RECOMMENDED | 高 | 部分符合 | SVG Tab 图标动态填色正确，其他组件颜色资源仍需治理。 |
| B05-R022 | REQUIRED | 高 | 符合 | 配置变化时动态设置状态栏和导航栏文字颜色。 |
| B05-R023 | REQUIRED | 条件性 | 不适用 | 工程未使用 Web 组件。 |

## 7. 汇总

| 分类 | 数量 | 说明 |
| --- | ---: | --- |
| 符合 | 12 | 已有可验证实现，后续只需防回归。 |
| 部分符合 | 45 | 本轮主要改造和验证对象。 |
| 不符合 | 5 | 表示当前差距，不等同于必须照搬某个示例实现；实施范围以核验后的级别和适用条件为准。 |
| 不适用/条件性 | 43 | 当前不形成实施要求；若条件变化需重新评估。 |
| 合计 | 105 | 覆盖 B01-B05 全部规则。 |

汇总数量只用于追踪覆盖率，不用于估算改造量或证明架构选择。实施期间任何规则
级别、来源或适用条件发生变化，都必须先更新本矩阵、`RULE_INDEX.md`、
`RULE_CONFLICTS.md` 和 `DECISIONS.md`，再修改应用代码。
