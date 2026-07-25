# Plan: Identify and document UI/UX loading/empty/error/animation/transition issues

## Summary

The user requested a scan of `/workspace/lib/` for UI/UX / visual design issues specifically related to loading states, empty states, error states, animations, transitions, skeleton screens, snackbars, and dialogs. At least 25 issues must be identified, categorized, assigned severity, described with `file://` links, and appended to `/tmp/speakflow-e2e-run/ui-ux-source-issues.md` (all in Chinese).

## Current state analysis

- The target markdown file already contains prior UI/UX findings (theme/colors/typography/spacing, responsive/layout, shell navigation, glassmorphism). A new section header should be added so the new issues are grouped separately.
- Loading/error/empty patterns are scattered across screens; there is no centralized loading widget. Common patterns observed:
  - `Center(child: CircularProgressIndicator())` used in `ChatMessageList`, `ProjectsScreen`, `ProgressScreen`, `PronunciationDetailScreen`, `HistoryScreen`, etc.
  - Error states are mostly plain `Center(Text(...))` with raw exception text and no retry affordance.
  - Empty states use a simple icon + text, sometimes without a clear CTA.
  - Animations are implemented ad-hoc with `AnimationController` in `ChatInputBar`, `ChatBubble`, `VirtualCharacter`, `VoiceStatusIndicator`, etc.
  - Page transitions live in `core/router/app_router.dart` (`_fadeTransitionPage`, `_slideTransitionPage`).
  - Feedback timing relies on `SnackBar`, `AlertDialog`, and inline retry hints.
- Based on the exploration, at least 25 distinct issues can be documented with concrete file locations and improvement suggestions.

## Proposed changes

1. **Read the target file** `/tmp/speakflow-e2e-run/ui-ux-source-issues.md` to confirm existing content and determine the next numbering range.
2. **Draft a new section** titled `## 新增：Loading / Empty / Error / Animation / Transition / Feedback Timing 问题` and continue the table format already used in the file (or the same heading structure if the file currently uses a table).
3. **Identify ≥25 issues** grounded in the explored source files. Example categories and representative locations:
   - **Loading states**: `chat_message_list.dart#L135`, `progress_screen.dart#L75`, `pronunciation_detail_screen.dart#L37`, `history_screen.dart#L184`, `projects_screen.dart#L41`.
   - **Empty states**: `chat_message_list.dart#L59-L88`, `history_screen.dart#L195-L220`, `projects_screen.dart#L79-L150`.
   - **Error states**: `chat_message_list.dart#L136-L137`, `projects_screen.dart#L42`, `progress_screen.dart#L76-L81`, `chat_screen.dart#L1198-L1230`.
   - **Animations / transitions**: `chat_bubble.dart#L222-L265` (cursor), `virtual_character.dart#L65-L147` (state/gesture), `app_router.dart#L203-L238` (transitions), `voice_status_indicator.dart#L46-L82`.
   - **Feedback timing**: `chat_input_bar.dart#L116-L138` (retry hint), `chat_screen.dart#L826-L828` (no-audio SnackBar), `chat_screen.dart#L1089-L1107` (config SnackBar).
4. **For each issue write** (in Chinese): 编号, 分类, 严重级别, 描述, 文件位置 (`file://...`), 建议改进.
5. **Append the markdown block** to the target file using the `Edit` tool.
6. **Verify** by re-reading the end of the target file and counting the appended issues.

## Assumptions & decisions

- The existing file uses a mix of `## N` headings and a later table section; to stay consistent with the most recent appended section, new issues will be appended as a table under a new `## 新增：...` header, continuing the numbering from `101` onward (or the next available number after existing entries) to avoid collisions.
- Issues will focus only on loading / empty / error / animation / transition / feedback timing, as requested, and will not duplicate the existing theme/color/spacing/responsive findings.
- Severity levels will be assigned as 高/中/低 based on user impact and frequency.
- No source code will be modified; only the markdown report is appended.

## Verification steps

1. Read `/tmp/speakflow-e2e-run/ui-ux-source-issues.md` after appending.
2. Confirm the new section header and all rows are present.
3. Count the appended issues and report the count to the user.
