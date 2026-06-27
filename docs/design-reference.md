# SpeakFlow — 设计参考资源

> 更新日期：2026-06-28
> 风格定位：Glassmorphism + 深色科技感 + 平台自适应

---

## 一、设计灵感来源

### 1.1 核心设计风格参考

| 风格 | 参考来源 | 链接 | 适用点 |
|------|---------|------|--------|
| **Glassmorphism** | glassmorphism.com | https://glassmorphism.com | 整体视觉基调：毛玻璃卡片、透明层叠 |
| **iOS 26 Liquid Glass** | Apple HIG | https://developer.apple.com/design/human-interface-guidelines/liquid-glass | iOS/macOS 端原生毛玻璃实现 |
| **Material You** | Material Design 3 | https://m3.material.io | Android 端组件规范 + Dynamic Color |
| **Vercel Geist** | Geist Design System | https://vercel.com/geist | 极简深色科技感参考 |
| **Shadcn/ui** | Shadcn UI | https://ui.shadcn.com | 组件设计思路、深色主题配色 |

### 1.2 AI 应用 UI 参考

| 产品/项目 | 风格特点 | 参考价值 |
|-----------|---------|---------|
| **ChatGPT** | 极简深色、清晰的对话气泡、圆角卡片 | 聊天界面布局、消息流设计 |
| **Claude.ai** | 温暖配色、柔和卡片、呼吸感 | AI 状态指示、消息排版 |
| **Perplexity** | 深色科技感、渐变高亮、搜索卡片 | 信息展示卡片设计 |
| **v0.dev** | 深色 + 代码高亮风格、极简 | 开发者向 AI 工具的视觉参考 |
| **Praktika** | 教育向、角色 + 聊天、活泼配色 | 学习类 AI 应用的 UI 模式 |
| **Speak** | 深色沉浸式、大字体、流体动画 | 录音交互、语音波形展示 |

---

## 二、设计系统参考

### 2.1 成熟设计系统（可借鉴 Token 命名与结构）

| 设计系统 | 链接 | 借鉴点 |
|---------|------|--------|
| **Vercel Geist** | https://vercel.com/geist | 深色主题色彩体系、间距规范 |
| **Shadcn/ui** | https://ui.shadcn.com | 组件 Token 结构、CSS 变量命名 |
| **Radix Colors** | https://www.radix-ui.com/colors | 12 级灰阶色板、语义色命名 |
| **Fluent UI** | https://fluent2.microsoft.design | 毛玻璃/Acrylic 材质参考（Windows） |
| **IBM Carbon** | https://carbondesignsystem.com | 严谨的 Token 体系、深色主题 |
| **Carbon Design AI** | https://carbondesignsystem.com/elements/color/usage | AI 相关色彩使用规范 |

### 2.2 Awesome 设计资源列表

| 资源 | 链接 | 说明 |
|------|------|------|
| **awesome-design-systems** | https://github.com/alexpate/awesome-design-systems | 5000+ ⭐ 最全设计系统合集 |
| **awesome-flutter** | https://github.com/Solido/awesome-flutter | 40k+ ⭐ Flutter 生态大全 |
| **design-resources-for-developers** | https://github.com/bradtraversy/design-resources-for-developers | 50k+ ⭐ 开发者设计资源合集 |
| **awesome-chatgpt-ui** | https://github.com/nextai-translator/awesome-chatgpt-ui | ChatGPT 类 UI 实现合集 |

---

## 三、Glassmorphism 实现参考

### 3.1 核心参数（Design Tokens）

```
/* Glassmorphism 通用 Design Tokens */

/* === 深色模式 === */
--glass-bg-dark:          rgba(255, 255, 255, 0.06);
--glass-bg-dark-hover:    rgba(255, 255, 255, 0.10);
--glass-bg-dark-active:   rgba(255, 255, 255, 0.14);
--glass-border-dark:      rgba(255, 255, 255, 0.08);
--glass-border-dark-glow: rgba(108, 92, 231, 0.3);   /* 紫色光晕 */
--glass-blur-dark:        20px;
--glass-shadow-dark:      0 8px 32px rgba(0, 0, 0, 0.3);

/* === 浅色模式 === */
--glass-bg-light:         rgba(255, 255, 255, 0.70);
--glass-bg-light-hover:   rgba(255, 255, 255, 0.85);
--glass-border-light:     rgba(255, 255, 255, 0.90);
--glass-blur-light:       20px;
--glass-shadow-light:     0 8px 32px rgba(0, 0, 0, 0.08);
```

### 3.2 Flutter 实现

```dart
// 毛玻璃卡片组件（核心）
Widget glassCard({required Widget child, Color? glowColor}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: [
            if (glowColor != null)
              BoxShadow(
                color: glowColor.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: -5,
              ),
          ],
        ),
        child: child,
      ),
    ),
  );
}
```

### 3.3 各平台 BackdropFilter 注意事项

| 平台 | 实现方式 | 注意点 |
|------|---------|--------|
| **iOS/macOS** | `BackdropFilter` 原生支持，性能好 | 可用系统 `UIVisualEffectView` 获取更原生效果 |
| **Android** | `BackdropFilter` 支持 | 部分低端机需降级为半透明纯色 |
| **Web** | CSS `backdrop-filter` | Safari 需 `-webkit-` 前缀；部分旧浏览器不支持 |
| **性能优化** | 控制同时渲染的毛玻璃层数 | 建议同时不超过 3-4 层，低端设备自动降级 |

---

## 四、色彩体系

### 4.1 完整色板

```
=== 背景色 ===
background-primary:     #0A0E1A  (深空蓝，主背景)
background-secondary:   #111827  (次级背景)
background-tertiary:    #1A2035  (卡片/面板背景)
background-surface:     rgba(255,255,255, 0.06)  (玻璃层)

=== 强调色 ===
accent-primary:         #6C5CE7  (紫色，AI/科技感)
accent-primary-light:   #A29BFE  (浅紫色)
accent-secondary:       #00D2FF  (青色，交互/活力)
accent-secondary-light: #74E8FF  (浅青色)

=== 语义色 ===
success:                #00E676  (成功/已掌握)
warning:                #FFB74D  (警告/待复习)
error:                  #FF5252  (错误/错误词高亮)
info:                   #42A5F5  (信息提示)

=== 文字色 ===
text-primary:           #F0F0F0  (主文字)
text-secondary:         #8892A4  (次级文字)
text-muted:             #5A6478  (辅助文字)
text-on-accent:         #FFFFFF  (强调色上的文字)

=== 灰阶（参考 Radix 12 级）===
gray-1:  #111113   gray-5:  #232530   gray-9:  #8B8D98
gray-2:  #18191B   gray-6:  #2E303C   gray-10: #AAACB6
gray-3:  #1E2024   gray-7:  #3E4050   gray-11: #C0C2CC
gray-4:  #212329   gray-8:  #626474   gray-12: #EDEDF0

=== 特效色 ===
glow-purple:            rgba(108, 92, 231, 0.3)   (紫色光晕)
glow-cyan:              rgba(0, 210, 255, 0.3)    (青色光晕)
glow-green:             rgba(0, 230, 118, 0.3)    (绿色光晕)
gradient-primary:       linear-gradient(135deg, #6C5CE7, #00D2FF)
gradient-bg:            linear-gradient(180deg, #0A0E1A, #111827)
```

### 4.2 语义色彩映射

| 场景 | 色彩 | 用途 |
|------|------|------|
| AI 消息气泡 | accent-primary (紫) + glow-purple | 左侧气泡，AI 角色相关 |
| 用户消息气泡 | accent-secondary (青) + glow-cyan | 右侧气泡 |
| 纠正气泡 | success (绿) + glow-green | 左侧，错误词用 error 色标注 |
| 录音按钮待机 | accent-secondary 柔和呼吸 | 脉冲外发光 |
| 录音按钮按下 | accent-secondary 强光 | 波纹扩散 |
| AI 思考中 | accent-primary (紫) 脉冲 | 背景微渐变 |
| AI 说话中 | success (绿) 脉冲 | 背景微渐变 |
| 加载骨架屏 | gray-5 → gray-6 微光扫描 | Shimmer 效果 |

---

## 五、字体排版

### 5.1 字体选择

```
英文字体：  Inter / SF Pro（系统） / Roboto（Android）
中文字体：  SF Pro（macOS/iOS） / Noto Sans SC（Android/Web）
代码字体：  JetBrains Mono / SF Mono
```

### 5.2 字号层级

```
Display:    32sp  / 700  (页面标题，极少用)
Heading:    24sp  / 600  (区域标题)
Title:      18sp  / 600  (卡片标题)
Body:       16sp  / 400  (正文、聊天消息)
Caption:    14sp  / 400  (辅助说明、时间戳)
Overline:   12sp  / 500  (标签、角标)
```

### 5.3 行高与间距

```
正文行高：  1.6
标题行高：  1.3
段落间距：  16px
气泡内边距：12px 16px
气泡间距：  12px
```

---

## 六、间距与圆角

### 6.1 间距系统（4px 基数）

```
xxs:  4px    (图标与文字间距)
xs:   8px    (紧凑元素间距)
sm:   12px   (气泡内边距)
md:   16px   (卡片内边距、区块间距)
lg:   24px   (大区块间距)
xl:   32px   (页面边距)
xxl:  48px   (屏幕级间距)
```

### 6.2 圆角规范

```
按钮/标签：    8px  (小元素)
输入框：      12px
卡片/气泡：   16px
大面板：      20px
录音按钮：    50%  (圆形)
头像：        50%  (圆形)
```

---

## 七、Flutter 包推荐

### 7.1 核心 UI 包

| 包名 | 用途 | 链接 |
|------|------|------|
| `flutter_animate` | 声明式动画，弹性曲线 | pub.dev/packages/flutter_animate |
| `shimmer` | 骨架屏加载微光效果 | pub.dev/packages/shimmer |
| `lottie` | Lottie 动画播放 | pub.dev/packages/lottie |
| `animated_text_kit` | 文字动画（打字机效果等） | pub.dev/packages/animated_text_kit |
| `wave` | 录音波形动画 | pub.dev/packages/wave |
| `flutter_blur` | 模糊效果辅助 | pub.dev/packages/flutter_blur |
| `flex_color_scheme` | Material 3 主题生成器 | pub.dev/packages/flex_color_scheme |
| `dynamic_color` | Android Dynamic Color 支持 | pub.dev/packages/dynamic_color |
| `forui` | Shadcn 风格 Flutter 组件库 | pub.dev/packages/forui |

### 7.2 参考项目

| 项目 | 链接 | 参考价值 |
|------|------|---------|
| **Flutter Neumorphic** | https://github.com/Idean/Flutter-Neumorphic | 毛玻璃/软阴影组件实现，2100+ ⭐ |
| **Forui** | https://github.com/forus-labs/forui | Shadcn 风格 Flutter 组件，1300+ ⭐ |
| **Shadcn Flutter** | https://github.com/nank1ro/flutter-shadcn | Shadcn/ui 的 Flutter 移植，2200+ ⭐ |

---

## 八、动画参考

### 8.1 录音交互动画

```
待机状态：
  ┌─────────────┐
  │    🎤       │  按钮 64px，玻璃质感
  │  白色呼吸光晕 │  外发光：opacity 0.3→0.6 循环 2s
  └─────────────┘

按下录音：
  ┌─────────────┐
  │    🎤       │  按钮缩放 0.95
  │  青色外发光   │  外发光变强：opacity 0.8
  │  ~~~涟漪~~~  │  2-3 层同心圆向外扩散，opacity 渐消
  └─────────────┘

松手发送：
  ┌─────────────┐
  │    ✈️       │  按钮弹回 1.0
  │  青色脉冲    │  最后一次涟漪 + 消散
  └─────────────┘
```

### 8.2 AI 状态指示动画

```
思考中：  紫色渐变背景缓慢流动，3 个圆点依次脉冲
说话中：  绿色渐变背景，角色嘴型同步
监听中：  青色渐变背景，录音波纹随声音大小变化
空闲：    深色毛玻璃，角色呼吸+眨眼待机
```

### 8.3 页面转场

```
主页 → 设置：  右侧毛玻璃面板滑入（300ms ease-out）
主页 → 历史：  左侧毛玻璃面板滑入
气泡出现：     底部弹性滑入 + opacity（250ms spring）
AI 角色切换：   crossfade + 缩放（400ms ease-in-out）
```

---

## 九、设计工具与资源

| 工具/资源 | 链接 | 用途 |
|----------|------|------|
| **Glassmorphism 生成器** | https://glassmorphism.com | 生成毛玻璃 CSS 参数 |
| **Radix Colors** | https://www.radix-ui.com/colors | 12 级色板参考 |
| **Realtime Colors** | https://www.realtimecolors.com | 实时预览配色方案 |
| **Figma Community** | https://www.figma.com/community | 搜索 "glassmorphism dark AI" 获取设计稿 |
| **LottieFiles** | https://lottiefiles.com | 免费 Lottie 动画素材 |
| **Google Fonts** | https://fonts.google.com | Inter 字体下载 |
| **Heroicons** | https://heroicons.com | 与 Tailwind 风格匹配的图标集 |
| **Lucide Icons** | https://lucide.dev | 清晰简洁的开源图标 |

---

## 十、无障碍设计

| 要求 | 标准 | 实现方式 |
|------|------|---------|
| 文字对比度 | WCAG AA (4.5:1) | 浅色文字 (#F0F0F0) 在深色背景 (#0A0E1A) 上 ≈ 17:1 |
| 玻璃层文字 | WCAG AA (4.5:1) | 玻璃层上加 0.8+ 不透明度底色确保可读 |
| 动画可关闭 | 系统设置尊重 | 读取系统 `reduce-motion` 设置，关闭动画 |
| 触摸目标 | 44x44pt 最小 | 录音按钮 64px，其他按钮 ≥ 44px |
| 色彩信息 | 不仅依赖颜色 | 错误词同时用红色 + 下划线 + (error) 标签 |
