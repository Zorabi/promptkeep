// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 dongx
import Foundation
@main struct CategoryTests {
    static func main() throws {
        let old = Data(#"{"prompts":[]}"#.utf8)
        let decoded = try JSONDecoder().decode(Library.self, from: old)
        assert(decoded.categories.isEmpty)
        var prompt = Prompt(); prompt.title = "测试"; prompt.content = "内容"; prompt.category = "旧分类"
        var library = Library(prompts: [prompt], categories: ["空分类"])
        assert(library.allCategories.contains("空分类"))
        library.renameCategory("旧分类", to: "新分类")
        assert(library.prompts[0].category == "新分类")
        assert(!library.allCategories.contains("旧分类"))
        library.deleteCategory("新分类")
        assert(library.prompts.count == 1 && library.prompts[0].content == "内容")
        assert(library.prompts[0].category == "未分类")
        assert(!library.allCategories.contains("新分类"))
        let roundtrip = try JSONDecoder().decode(Library.self, from: JSONEncoder().encode(library))
        assert(roundtrip.allCategories == ["空分类"])
        assert(decoded.tags.isEmpty)
        prompt.tags = ["旧标签", "已有"]
        var organized = Library(prompts: [prompt], categories: ["目标分类"], tags: ["空标签", "新增"])
        organized.renameTag("旧标签", to: "新标签")
        assert(organized.prompts[0].tags == ["新标签", "已有"])
        organized.deleteTag("新标签")
        assert(organized.prompts[0].tags == ["已有"])
        let before = organized.prompts[0]
        assert(!organized.organize(ids: [prompt.id, "unknown"], category: "目标分类"))
        assert(organized.prompts[0] == before)
        assert(!organized.organize(ids: [prompt.id], tag: "不存在"))
        assert(organized.organize(ids: [prompt.id], category: "目标分类"))
        assert(organized.prompts[0].category == "目标分类")
        assert(organized.organize(ids: [prompt.id], tag: "新增"))
        assert(organized.organize(ids: [prompt.id], tag: "新增"))
        assert(organized.prompts[0].tags == ["已有", "新增"])
        assert(organized.prompts[0].content == before.content)
        assert(organized.prompts[0].versions == before.versions)
        assert(organized.prompts[0].uses == before.uses)
        let tagsRoundtrip = try JSONDecoder().decode(Library.self, from: JSONEncoder().encode(organized))
        assert(tagsRoundtrip.allTags.contains("空标签"))
        print("标签与拖放验证通过：旧数据兼容、空标签备份、重命名与删除联动、分类移动、标签追加去重、无效批次不修改内容")
        print("分类验证通过：旧备份兼容、空分类持久化、重命名联动、删除保留提示词、备份往返")
    }
}
