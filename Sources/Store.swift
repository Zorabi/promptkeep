// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 dongx
import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers

final class Store: ObservableObject {
    @Published var library = Library()
    @Published var error: String?
    @Published private(set) var drafts: [String: TextDraft] = [:]
    private let draftFile: URL
    let file: URL
    init(directory: URL? = nil) {
        let folder = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("dongx.promptkeep", isDirectory: true)
        file = folder.appendingPathComponent("library.json")
        draftFile = folder.appendingPathComponent("drafts.json")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: file.path) { library = try JSONDecoder().decode(Library.self, from: Data(contentsOf: file)) }
            if FileManager.default.fileExists(atPath: draftFile.path) {
                let saved = try JSONDecoder().decode([String: TextDraft].self, from: Data(contentsOf: draftFile))
                drafts = saved.filter { key, draft in library.prompts.contains { $0.id == key && TextDraft($0) != draft } }
            }
        } catch { self.error = "无法读取资料库或草稿：\(error.localizedDescription)" }
    }
    func draft(for prompt: Prompt) -> TextDraft { drafts[prompt.id] ?? TextDraft(prompt) }
    @discardableResult private func persistDrafts(_ next: [String: TextDraft]) -> Bool {
        do {
            try JSONEncoder().encode(next).write(to: draftFile, options: .atomic)
            drafts = next
            return true
        } catch { self.error = "草稿保存失败：\(error.localizedDescription)"; return false }
    }
    @discardableResult func updateDraft(id: String, _ draft: TextDraft) -> Bool {
        guard let prompt = library.prompts.first(where: { $0.id == id }) else { return false }
        var next = drafts
        if draft == TextDraft(prompt) { next.removeValue(forKey: id) } else { next[id] = draft }
        return persistDrafts(next)
    }
    @discardableResult func discardDraft(_ id: String) -> Bool {
        var next = drafts; next.removeValue(forKey: id); return persistDrafts(next)
    }
    @discardableResult func saveDraft(_ id: String) -> Bool {
        guard let draft = drafts[id], draft.canSave,
              var prompt = library.prompts.first(where: { $0.id == id }) else { return false }
        prompt.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        prompt.content = draft.content
        prompt.result = draft.result
        guard save(prompt) else { return false }
        return discardDraft(id)
    }
    @discardableResult func commit(_ next: Library) -> Bool {
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(next).write(to: file, options: .atomic)
            library = next
            return true
        } catch { self.error = "保存失败：\(error.localizedDescription)"; return false }
    }
    @discardableResult func save(_ prompt: Prompt) -> Bool {
        var next = library; var item = prompt
        if let i = next.prompts.firstIndex(where: {$0.id == item.id}) {
            let old = next.prompts[i]
            if old.content != item.content || old.result != item.result {
                item.versions = old.versions + [Revision(date: old.updated, content: old.content, result: old.result)]
            }
            item.updated = ISO8601DateFormatter().string(from: Date()); next.prompts[i] = item
        } else { next.prompts.insert(item, at: 0) }
        next.categories = next.allCategories
        next.tags = next.allTags
        return commit(next)
    }
    var categories: [String] { library.allCategories }
    @discardableResult func setCategory(_ raw: String, replacing old: String? = nil) -> Bool {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != "未分类" else { error = "请输入分类名称，「未分类」为系统保留名称。"; return false }
        guard name == old || !categories.contains(where: { $0.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) else { error = "这个分类已存在。"; return false }
        var next = library
        if let old { next.renameCategory(old, to: name) }
        else { next.categories = next.allCategories + [name] }
        return commit(next)
    }
    @discardableResult func deleteCategory(_ name: String) -> Bool {
        var next = library; next.deleteCategory(name); return commit(next)
    }
    var tags: [String] { library.allTags }
    @discardableResult func setTag(_ raw: String, replacing old: String? = nil) -> Bool {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !name.contains(","), !name.contains("，") else { error = "请输入标签名称，名称中不能包含逗号。"; return false }
        guard name == old || !tags.contains(where: { $0.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) else { error = "这个标签已存在。"; return false }
        var next = library
        if let old { next.renameTag(old, to: name) }
        else { next.tags = next.allTags + [name] }
        return commit(next)
    }
    @discardableResult func deleteTag(_ name: String) -> Bool {
        var next = library; next.deleteTag(name); return commit(next)
    }
    func organize(ids: [String], category: String? = nil, tag: String? = nil) -> Bool {
        var next = library
        guard next.organize(ids: ids, category: category, tag: tag) else { return false }
        return commit(next)
    }
    func remove(_ id: String) { var next = library; next.prompts.removeAll {$0.id == id}; if commit(next) { discardDraft(id) } }
    func exportFile() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "词笺-backup.json"
        if panel.runModal() == .OK, let url = panel.url {
            do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted]; try encoder.encode(library).write(to: url, options: .atomic) }
            catch { self.error = "导出失败：\(error.localizedDescription)" }
        }
    }
    func importFile() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                guard data.count <= 10 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
                let incoming = try JSONDecoder().decode(Library.self, from: data)
                var next = library; var ids = Set(next.prompts.map(\.id))
                for p in incoming.prompts where ids.insert(p.id).inserted { next.prompts.append(p) }
                next.categories = Array(Set(next.allCategories + incoming.allCategories))
                next.tags = Array(Set(next.allTags + incoming.allTags))
                commit(next)
            } catch { self.error = "导入失败，请选择词笺 JSON 备份：\(error.localizedDescription)" }
        }
    }
}
