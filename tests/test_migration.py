# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (c) 2026 dongx
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('converter', Path(__file__).parents[1] / 'scripts/convert-promptflow.py')
converter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(converter)

class MigrationTests(unittest.TestCase):
    def source(self):
        return {'data': {'tags': [{'id':'tag','name':'写作'}], 'categories':[{'id':'cat','name':'工作'}], 'prompts':[{'id':'one','name':'模板','content':'原文\n{{主题}}','tagIds':['tag'],'categoryId':'cat','isPinned':True,'useCount':3,'updatedAt':'2026-10-28T11:00:00.000','description':'使用心得'}]}}

    def test_preserve_fields_and_stable_id(self):
        first = converter.convert(self.source())['prompts'][0]
        self.assertEqual(first['id'], converter.convert(self.source())['prompts'][0]['id'])
        self.assertEqual(first['content'], '原文\n{{主题}}')
        self.assertEqual(first['tags'], ['写作'])
        self.assertEqual(first['category'], '工作')
        self.assertTrue(first['favorite'])
        self.assertEqual(first['uses'], 3)
        self.assertEqual(first['result'], '使用心得')
        self.assertEqual(first['versions'], [])

    def test_attachments_are_not_silently_lost(self):
        source = self.source()
        source['data']['prompts'][0]['referenceImages'] = ['image']
        with self.assertRaises(ValueError): converter.convert(source)

if __name__ == '__main__': unittest.main()
