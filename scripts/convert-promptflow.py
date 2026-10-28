#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (c) 2026 dongx
"""将 PromptFlow JSON 完整备份转换为 PromptKeep 可导入备份。"""
import argparse
import json
from datetime import datetime
from pathlib import Path


def convert(source):
    data = source['data']
    tags = {t['id']: t['name'] for t in data['tags']}
    categories = {c['id']: c['name'] for c in data['categories']}
    prompts = []
    for p in data['prompts']:
        if p.get('aiResults') or p.get('referenceImages'):
            raise ValueError('该备份含结果或图片附件，请先单独保存附件，避免遗漏')
        stamp = datetime.fromisoformat(p['updatedAt'].replace('Z', '+00:00'))
        if stamp.tzinfo is None:
            stamp = stamp.astimezone()
        prompts.append(dict(
            id='promptflow:' + p['id'], title=p['name'], content=p['content'],
            category=categories.get(p.get('categoryId'), '未分类'),
            tags=[tags[t] for t in p.get('tagIds', [])], result=p.get('description', ''),
            favorite=p.get('isPinned', False), uses=p.get('useCount', 0),
            updated=stamp.isoformat(), versions=[]))
    return {'prompts': prompts}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    result = convert(json.loads(args.source.read_text()))
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2))
    print('已转换 %d 条提示词' % len(result['prompts']))


if __name__ == '__main__':
    main()
