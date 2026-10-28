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
        print("分类验证通过：旧备份兼容、空分类持久化、重命名联动、删除保留提示词、备份往返")
    }
}
