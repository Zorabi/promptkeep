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
    enum CodingKeys: String, CodingKey { case prompts, categories }
    init(prompts: [Prompt] = [], categories: [String] = []) {
        self.prompts = prompts; self.categories = categories
    }
    init(from decoder: Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        prompts = try box.decode([Prompt].self, forKey: .prompts)
        categories = try box.decodeIfPresent([String].self, forKey: .categories) ?? []
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
}
