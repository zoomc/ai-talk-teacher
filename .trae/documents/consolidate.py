#!/usr/bin/env python3
"""Consolidate four issue reports into a unified modification list."""
import re
from pathlib import Path

ROOT = Path('/tmp/speakflow-e2e-run')
SOURCES = {
    'BL': ('business-logic-issues.md', '业务逻辑 / 交互'),
    'UX': ('ui-ux-source-issues.md', 'UI/UX / 视觉设计（源码）'),
    'VA': ('visual-analysis-issues.md', '视觉分析（截图）'),
    'E2E': ('e2e-coverage-gaps.md', 'E2E 覆盖缺口'),
}

OUTPUT = ROOT / 'unified-modifications.md'

def extract_items(text: str, prefix: str):
    """Extract numbered items by looking for numbered headings/paragraphs."""
    items = []
    pattern = re.compile(
        r'(?:^|\n)(?:#{1,3}\s+(\d+)[\.\)]?\s*|'
        r'(\d+)\.\s+\*\*[^*]+\*\*|'
        r'\*\*(\d+)[\.\)]?\s*[^*]*\*\*)',
        re.MULTILINE,
    )
    matches = list(pattern.finditer(text))
    for i, m in enumerate(matches):
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        block = text[start:end].strip()
        if block:
            items.append(block)
    return items

def main():
    total = 0
    sections = []
    for prefix, (filename, title) in SOURCES.items():
        path = ROOT / filename
        text = path.read_text(encoding='utf-8')
        items = extract_items(text, prefix)
        if len(items) < 5:
            items = [text]
        sections.append((prefix, title, filename, items))
        total += len(items)

    lines = [
        '# SpeakFlow 统一修改点清单',
        '',
        '> 生成日期：2026-07-25',
        '> 来源：业务逻辑审查、UI/UX 源码审查、截图视觉分析、E2E 覆盖缺口',
        '',
        '## 汇总统计',
        '',
        '| 来源 | 文件 | 修改点数量 |',
        '|------|------|-----------|',
    ]
    for prefix, title, filename, items in sections:
        lines.append(f'| {title} | [{filename}](file:///tmp/speakflow-e2e-run/{filename}) | {len(items)} |')
    lines.append(f'| **合计** | - | **{total}** |')
    lines.append('')
    lines.append('## 修改点分类索引')
    lines.append('')
    lines.append('- 交互与业务逻辑：见「业务逻辑 / 交互」章节')
    lines.append('- UI/UX 与视觉：见「UI/UX / 视觉设计（源码）」与「视觉分析（截图）」章节')
    lines.append('- E2E 测试补强：见「E2E 覆盖缺口」章节')
    lines.append('')

    for prefix, title, filename, items in sections:
        lines.append(f'## {title}（{len(items)} 条）')
        lines.append('')
        for idx, item in enumerate(items, start=1):
            uid = f'{prefix}-{idx:03d}'
            lines.append(f'### {uid}')
            lines.append('')
            lines.append(item)
            lines.append('')

    OUTPUT.write_text('\n'.join(lines), encoding='utf-8')
    print(f'Wrote {total} items to {OUTPUT}')

if __name__ == '__main__':
    main()
