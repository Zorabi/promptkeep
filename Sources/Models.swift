// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 dongx
import Foundation

struct Revision: Codable, Identifiable, Hashable {
    var id: String { date }
    var date: String
    var content: String
    var result: String
}
struct Prompt: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var title = ""
    var content = ""
    var category = "未分类"
    var tags: [String] = []
    var result = ""
    var favorite = false
    var uses = 0
    var updated = ISO8601DateFormatter().string(from: Date())
    var versions: [Revision] = []
}
struct Library: Codable {
    var prompts: [Prompt] = []
    var categories: [String] = []
    var tags: [String] = []
    enum CodingKeys: String, CodingKey { case prompts, categories, tags }
    init(prompts: [Prompt] = [], categories: [String] = [], tags: [String] = []) {
        self.prompts = prompts; self.categories = categories; self.tags = tags
    }
    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        prompts = try box.decode([Prompt].self, forKey: .prompts)
        categories = try box.decodeIfPresent([String].self, forKey: .categories) ?? []
        tags = try box.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
    var allCategories: [String] {
        Array(Set(categories + prompts.map(\.category))).filter { !$0.isEmpty && $0 != "未分类" }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    mutating func renameCategory(_ old: String, to name: String) {
        categories = allCategories.map { $0 == old ? name : $0 }
        for i in prompts.indices where prompts[i].category == old { prompts[i].category = name }
    }
    mutating func deleteCategory(_ name: String) {
        categories = allCategories.filter { $0 != name }
        for i in prompts.indices where prompts[i].category == name { prompts[i].category = "未分类" }
    }
    var allTags: [String] {
        Array(Set(tags + prompts.flatMap(\.tags))).filter { !$0.isEmpty }.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    mutating func renameTag(_ old: String, to name: String) {
        tags = allTags.map { $0 == old ? name : $0 }
        for i in prompts.indices {
            prompts[i].tags = prompts[i].tags.map { $0 == old ? name : $0 }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        }
    }
    mutating func deleteTag(_ name: String) {
        tags = allTags.filter { $0 != name }
        for i in prompts.indices { prompts[i].tags.removeAll { $0 == name } }
    }
    @discardableResult mutating func organize(ids: [String], category: String? = nil, tag: String? = nil) -> Bool {
        let selected = Set(ids)
        guard !selected.isEmpty, selected.isSubset(of: Set(prompts.map(\.id))),
              category != nil || tag != nil,
              category == nil || category == "未分类" || allCategories.contains(category!),
              tag == nil || allTags.contains(tag!) else { return false }
        for i in prompts.indices where selected.contains(prompts[i].id) {
            var changed = false
            if let category, prompts[i].category != category { prompts[i].category = category; changed = true }
            if let tag, !prompts[i].tags.contains(tag) { prompts[i].tags.append(tag); changed = true }
            if changed { prompts[i].updated = ISO8601DateFormatter().string(from: Date()) }
        }
        return true
    }

}
