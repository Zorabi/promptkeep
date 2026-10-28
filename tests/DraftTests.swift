// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 dongx
import Foundation
@main struct DraftTests {
    static func main() throws {
        let folder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("build/tests/drafts-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = Store(directory: folder)
        var original = Prompt(); original.title = "原始标题"; original.content = "原文 {{主题}}"; original.result = "原笔记"
        assert(store.save(original))
        var second = Prompt(); second.title = "另一条"; second.content = "另一个正文"
        assert(store.save(second))
        var draft = TextDraft(original); draft.title = "新标题"; draft.content = "修改正文 {{主题}}"; draft.result = "新笔记"
        assert(store.updateDraft(id: original.id, draft))
        assert(store.draft(for: second) == TextDraft(second))
        assert(store.library.prompts.first { $0.id == original.id }!.content == original.content)
        let restarted = Store(directory: folder)
        assert(restarted.drafts[original.id] == draft)
        assert(restarted.setCategory("工作"))
        assert(restarted.setTag("常用"))
        assert(restarted.organize(ids: [original.id], category: "工作", tag: "常用"))
        assert(restarted.saveDraft(original.id))
        let saved = restarted.library.prompts.first { $0.id == original.id }!
        assert(saved.title == draft.title && saved.content == draft.content && saved.result == draft.result)
        assert(saved.category == "工作" && saved.tags == ["常用"])
        assert(saved.versions.count == 1 && saved.versions[0].content == original.content)
        assert(restarted.drafts[original.id] == nil)
        let cleanRestart = Store(directory: folder)
        assert(cleanRestart.drafts.isEmpty)
        var invalid = TextDraft(saved); invalid.content = "  "
        assert(cleanRestart.updateDraft(id: original.id, invalid))
        assert(!cleanRestart.saveDraft(original.id))
        assert(cleanRestart.drafts[original.id] == invalid)
        assert(cleanRestart.discardDraft(original.id))
        assert(cleanRestart.draft(for: saved) == TextDraft(saved))
        assert(!cleanRestart.updateDraft(id: "unknown", draft))
        print("草稿验证通过：跨记录保留、重启恢复、保存合并最新分类标签、历史版本、空正文拦截、取消修改、未知记录拒绝")
    }
}
