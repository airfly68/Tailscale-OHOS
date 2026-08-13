/**
 * Release changelog editor
 *
 * 每次准备发布时只编辑本文件：
 * 1. 把最新版本放在 RELEASE_CHANGELOG_ENTRIES 的第一项；
 * 2. 让 versionName/versionCode 与 AppScope/app.json5 完全一致；
 * 3. 填写至少一条中英文更新内容和发布日期；
 * 4. 旧版本按时间顺序保留在后面。
 *
 * Release 构建会校验第一项，内容为空或版本不一致时会直接失败。
 */
export interface ReleaseChangelogDefinition {
  versionName: string;
  versionCode: number;
  releaseDateZh: string;
  releaseDateEn: string;
  changesZh: string[];
  changesEn: string[];
}

export const RELEASE_CHANGELOG_ENTRIES: ReleaseChangelogDefinition[] = [
  {
    versionName: '0.9.10',
    versionCode: 99000003,
    releaseDateZh: '2026年8月10日',
    releaseDateEn: 'August 10, 2026',
    changesZh: [
      '新增更新后首次打开时显示的半模态更新日志',
      '更新 HosPlayer 服务器导入链接',
      '修复连接、传输和媒体联动中的若干边界问题'
    ],
    changesEn: [
      'Added a half-modal release log on the first launch after an update',
      'Updated the HosPlayer server import handoff',
      'Fixed several connection, transfer, and media integration edge cases'
    ]
  },
  {
    versionName: '0.9.10',
    versionCode: 99000002,
    releaseDateZh: '2026年8月3日',
    releaseDateEn: 'August 3, 2026',
    changesZh: [
      '完善 MeshSend 文件传输流程',
      '优化响应式首页布局',
      '增加 VPN 与媒体联动诊断'
    ],
    changesEn: [
      'Expanded the MeshSend file transfer flow',
      'Polished the responsive home layout',
      'Added VPN and media integration diagnostics'
    ]
  },
  {
    versionName: '0.9.8',
    versionCode: 9800000,
    releaseDateZh: '2026年7月29日',
    releaseDateEn: 'July 29, 2026',
    changesZh: [
      '完成 Taildrop 收发文件流程',
      '增加媒体服务发现',
      '改进 VPN 启动与恢复'
    ],
    changesEn: [
      'Completed the Taildrop send and receive flow',
      'Added media service discovery',
      'Improved VPN startup and recovery'
    ]
  }
];
