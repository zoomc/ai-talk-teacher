# 数据兼容与迁移说明

核查日期：2026-08-04

## 兼容策略

当前 SQLite/IndexedDB schema version 为 10，迁移入口是
`lib/core/database/database_helper.dart` 的 `DatabaseHelper._onUpgrade`。迁移只做
向前的 additive change；不删除用户数据，不重写已有主键，也不因首页或导航调整而
清空会话、纠错、复习或 Provider 配置。

| 版本 | 主要内容 | 迁移方式 |
|---|---|---|
| v1 → v2 | Provider catalog 字段与 legacy provider 映射 | 加列、回填 provider/base URL/model |
| v2 → v3 | correction 去重字段 | 加 `occurrence_count`、`last_seen_at` 并回填 |
| v3 → v4 | 收藏/重要度、guest session | 加默认值字段 |
| v4 → v5 | phoneme score 表 | `CREATE TABLE IF NOT EXISTS` |
| v5 → v6 | practice log、review queue | 建表并从 corrections 回填 due time |
| v6 → v7 | skill、SM-2 队列字段、mastery、goal | 加列、回填 SM-2 状态、建表 |
| v7 → v8 | scenario content、teacher persona、scenario review | 加列、建表、幂等 seed |
| v8 → v9 | projects、links、activities | 幂等建表，无破坏性回填 |
| v9 → v10 | pronunciation report、weak areas、snapshot、suggestion、session metadata | 幂等建表，无历史数据删除 |

## 敏感数据

- `llm_profiles.api_key`、`stt_profiles.api_key`、`tts_profiles.api_key` 的真实值由
  `SecureStorageService` 保存；SQLite metadata 只允许 `***stored***` 占位符。
- 导出、日志、PWA cache、URL、构建产物不得包含真实 key、Authorization header、录音
  或动态 AI 响应。
- Web 端的 secure storage 仍受浏览器/XSS 威胁，不能等同于原生 Keychain/Keystore；
  需要更高安全等级时应使用同源后端 relay，不把 key 发送到应用构建物。

## 导航与数据

根路由改成练习入口，旧 dashboard 仍位于 `/dashboard`；`/scenarios`、`/history`、
`/projects` 等降为二级入口，但对应表和 Repository 保留。session、message、correction
的外键关联不因 UI 收敛而改变。

## 回归要求

每次 schema version 变化必须同时：

1. 增加 `oldVersion < N` 分支，保证升级顺序和幂等性；
2. 为已有行提供安全默认值或明确回填；
3. 验证 fresh install 与旧库升级两条路径；
4. 运行 `flutter test`，并在 E2E 中通过 bridge 检查 chat/session/correction/review
   数据仍可读写；
5. 若涉及敏感字段，做 key/URL/log/cache 扫描。

当前没有将真实用户数据库复制到仓库；发布前应在备份副本上执行 v1、v5、v9 的升级演练，
并保留 schema dump 与回滚备份。SQLite migration 本身不支持安全的“降级”，回滚策略是
恢复升级前数据库备份并回滚应用版本，而不是执行反向 SQL。
