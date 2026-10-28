// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 dongx
import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension View {
    @ViewBuilder func quietFocus() -> some View {
        if #available(macOS 14.0, *) { self.focusEffectDisabled() }
        else { self }
    }
}
struct QuietButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10).padding(.vertical, 6)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background(prominent ? Color.accentColor.opacity(configuration.isPressed ? 0.7 : 1) : Color.primary.opacity(configuration.isPressed ? 0.06 : 0))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
final class Store: ObservableObject {
    @Published var library = Library()
    @Published var error: String?
    let file: URL
    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("dongx.promptkeep", isDirectory: true)
        file = folder.appendingPathComponent("library.json")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: file.path) { library = try JSONDecoder().decode(Library.self, from: Data(contentsOf: file)) }
        } catch { self.error = "无法读取资料库：\(error.localizedDescription)" }
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
    func remove(_ id: String) { var next = library; next.prompts.removeAll {$0.id == id}; commit(next) }
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
                commit(next)
            } catch { self.error = "导入失败，请选择词笺 JSON 备份：\(error.localizedDescription)" }
        }
    }
}

struct Editor: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: Store
    @State var prompt: Prompt
    @State private var tags = ""
    @State private var dirty = false
    @State private var confirmClose = false
    var onSave: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(prompt.title.isEmpty ? "新建提示词" : "编辑提示词").font(.title2.bold())
            TextField("标题", text: $prompt.title).textFieldStyle(.roundedBorder)
            HStack {
                Picker("分类", selection: $prompt.category) {
                    Text("未分类").tag("未分类")
                    ForEach(store.categories, id: \.self) { Text($0).tag($0) }
                }
                TextField("标签，用逗号分隔", text: $tags).textFieldStyle(.roundedBorder)
            }
            Text("提示词内容").font(.headline)
            Text("使用 {{变量名}} 创建可填充的模板").font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $prompt.content).font(.body.monospaced()).padding(8).background(.background).clipShape(RoundedRectangle(cornerRadius: 8)).frame(minHeight: 200)
            Text("使用笔记（可选）").font(.headline)
            TextEditor(text: $prompt.result).padding(8).background(.background).clipShape(RoundedRectangle(cornerRadius: 8)).frame(height: 115)
            HStack {
                Button("取消") { if dirty { confirmClose = true } else { dismiss() } }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存提示词") {
                    prompt.title = prompt.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    prompt.category = prompt.category.trimmingCharacters(in: .whitespacesAndNewlines)
                    if prompt.category.isEmpty { prompt.category = "未分类" }
                    prompt.tags = tags.replacingOccurrences(of: "，", with: ",").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter {!$0.isEmpty}
                    if store.save(prompt) { onSave(prompt.id); dismiss() }
                }.keyboardShortcut(.defaultAction).buttonStyle(QuietButtonStyle(prominent: true)).disabled(prompt.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || prompt.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(26).frame(width: 640).onAppear { tags = prompt.tags.joined(separator: ", ") }
        .onChange(of: prompt.title) { _ in dirty = true }.onChange(of: prompt.content) { _ in dirty = true }.onChange(of: prompt.result) { _ in dirty = true }.onChange(of: prompt.category) { _ in dirty = true }.onChange(of: tags) { _ in dirty = true }
        .interactiveDismissDisabled(dirty)
        .confirmationDialog("放弃尚未保存的修改？", isPresented: $confirmClose) { Button("放弃修改", role: .destructive) { dismiss() } }
    }
}

struct Detail: View {
    @EnvironmentObject var store: Store
    var prompt: Prompt
    var edit: () -> Void
    @State private var section = 0
    @State private var values: [String: String] = [:]
    @State private var copied = false
    @State private var restore: Revision?
    var variables: [String] {
        let regex = try! NSRegularExpression(pattern: #"\{\{([^{}]+)\}\}"#)
        let text = prompt.content as NSString
        var seen = Set<String>()
        return regex.matches(in: prompt.content, range: NSRange(location: 0, length: text.length)).map { text.substring(with: $0.range(at: 1)) }.filter { seen.insert($0).inserted }
    }
    var filled: String { variables.reduce(prompt.content) { text, key in let value = values[key] ?? ""; return value.isEmpty ? text : text.replacingOccurrences(of: "{{\(key)}}", with: value) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(prompt.category).font(.caption).padding(.horizontal, 10).padding(.vertical, 5).background(Color.accentColor.opacity(0.1)).clipShape(Capsule())
                Spacer()
                Button { var p = prompt; p.favorite.toggle(); store.save(p) } label: { Image(systemName: prompt.favorite ? "star.fill" : "star") }.help("收藏")
                Button("编辑", action: edit)
            }
            Text(prompt.title).font(.system(size: 27, weight: .bold, design: .rounded)).textSelection(.enabled)
            Text(prompt.tags.map { "#\($0)" }.joined(separator: "   ")).foregroundStyle(.secondary).font(.caption)
            Picker("内容", selection: $section) { Text("提示词").tag(0); Text("使用笔记").tag(1); Text("历史版本 · \(prompt.versions.count)").tag(2) }.pickerStyle(.segmented)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if section == 2 {
                        if prompt.versions.isEmpty { Text("编辑内容并保存后，旧版本会保留在这里。").foregroundStyle(.secondary).padding(.top, 30) }
                        ForEach(Array(prompt.versions.enumerated().reversed()), id: \.offset) { _, version in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(version.date.prefix(10)).font(.caption).foregroundStyle(.secondary)
                                Text(version.content).lineLimit(7).textSelection(.enabled)
                                Button("恢复此版本") { restore = version }
                            }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    } else {
                        Text(section == 0 ? filled : (prompt.result.isEmpty ? "记录适用场景、使用方法或改进想法。点击编辑添加。" : prompt.result))
                            .font(.system(size: 14)).lineSpacing(7).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(20).background(Color(nsColor: .textBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 12))
                        if section == 0 && !variables.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("填写模板变量", systemImage: "slider.horizontal.3").font(.headline)
                                ForEach(variables, id: \.self) { key in
                                    VStack(alignment: .leading) { Text(key).font(.caption).foregroundStyle(.secondary); TextField("输入\(key)", text: Binding(get: { values[key] ?? "" }, set: { values[key] = $0 })).textFieldStyle(.roundedBorder) }
                                }
                            }.padding(18).background(Color.accentColor.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }.padding(.vertical, 2)
            }
            if section != 2 {
                Button {
                    NSPasteboard.general.clearContents(); NSPasteboard.general.setString(section == 0 ? filled : prompt.result, forType: .string)
                    var p = prompt; p.uses += 1; store.save(p); copied = true
                } label: { Label(copied ? "已复制" : "复制\(section == 0 ? "提示词" : "笔记")", systemImage: copied ? "checkmark" : "doc.on.doc").frame(maxWidth: .infinity).padding(7) }.buttonStyle(QuietButtonStyle(prominent: true)).disabled(section == 1 && prompt.result.isEmpty)
                Text("已复制 \(prompt.uses) 次 · 数据仅保存在本机").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(28).frame(minWidth: 360)
        .onChange(of: prompt.id) { _ in values = [:]; section = 0; copied = false }
        .onChange(of: values) { _ in copied = false }
        .confirmationDialog("恢复此版本？当前内容会保留为历史版本。", isPresented: Binding(get: { restore != nil }, set: { if !$0 { restore = nil } })) {
            Button("恢复版本") { if let v = restore { var p = prompt; p.content = v.content; p.result = v.result; store.save(p); section = 0 }; restore = nil }
        }
    }
}
struct CategoryManager: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var editing: String?
    @State private var deleting: String?
    var onRename: (String, String) -> Void
    var onDelete: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("分类管理").font(.title2.bold())
                    Text("先建分类，再慢慢收集好用的提示词。").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            HStack {
                TextField(editing == nil ? "新分类名称" : "新的分类名称", text: $name).textFieldStyle(.roundedBorder)
                    .onSubmit { save() }
                if editing != nil { Button("取消重命名") { editing = nil; name = "" } }
                Button(editing == nil ? "添加分类" : "保存名称") { save() }
                    .buttonStyle(QuietButtonStyle(prominent: true))
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            ScrollView {
                VStack(spacing: 8) {
                    HStack {
                        Label("未分类", systemImage: "tray")
                        Spacer()
                        Text("系统分类").font(.caption).foregroundStyle(.secondary)
                    }.padding(12)
                    ForEach(store.categories, id: \.self) { category in
                        HStack {
                            Label(category, systemImage: "folder")
                            Text("\(store.library.prompts.filter { $0.category == category }.count) 条").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("重命名") { editing = category; name = category }
                            Button("删除", role: .destructive) { deleting = category }
                        }.padding(12).background(Color.primary.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    if store.categories.isEmpty { Text("还没有自定义分类，添加后会显示在侧边栏。").font(.callout).foregroundStyle(.secondary).padding(24) }
                }
            }
            Text("删除分类不会删除提示词，内容会移入「未分类」。").font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(width: 580, height: 430)
        .confirmationDialog("删除「\(deleting ?? "")」分类？其中的提示词将移到「未分类」。", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("删除分类", role: .destructive) {
                if let category = deleting, store.deleteCategory(category) {
                    onDelete(category)
                    if editing == category { editing = nil; name = "" }
                }
                deleting = nil
            }
        }
        .alert("操作未完成", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("好") { store.error = nil } } message: { Text(store.error ?? "") }
    }
    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if store.setCategory(trimmed, replacing: editing) {
            if let editing { onRename(editing, trimmed) }
            editing = nil; name = ""
        }
    }
}
struct ContentView: View {
    @EnvironmentObject var store: Store
    @State private var filter = "全部提示词"
    @State private var search = ""
    @State private var selected: String?
    @State private var editor: Prompt?
    @State private var deletion: Prompt?
    @State private var sort = 0
    @State private var managingCategories = false
    var categories: [String] { ["未分类"] + store.categories }
    var filtered: [Prompt] {
        store.library.prompts.filter { p in
            (filter == "全部提示词" || filter == "我的收藏" && p.favorite || filter == "最近使用" && p.uses > 0 || filter == "分类:" + p.category) && (search.isEmpty || ([p.title, p.content, p.result] + p.tags).joined(separator: " ").localizedCaseInsensitiveContains(search))
        }.sorted { a,b in sort == 1 ? a.title.localizedCompare(b.title) == .orderedAscending : sort == 2 ? a.uses > b.uses : a.updated > b.updated }
    }
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) { Image(systemName: "text.book.closed.fill").font(.title).foregroundStyle(Color.accentColor); VStack(alignment: .leading) { Text("词笺").font(.headline); Text("你的私人提示词工作台").font(.caption2).foregroundStyle(.secondary) } }.padding(18)
                Button { editor = Prompt() } label: { Label("新建提示词", systemImage: "plus").frame(maxWidth: .infinity).padding(5) }.buttonStyle(QuietButtonStyle(prominent: true)).padding(.horizontal, 16).padding(.bottom, 16).keyboardShortcut("n")
                List(selection: $filter) {
                    Section("资料库") {
                        Label("全部提示词", systemImage: "square.grid.2x2").tag("全部提示词")
                        Label("我的收藏", systemImage: "star").tag("我的收藏")
                        Label("最近使用", systemImage: "clock").tag("最近使用")
                    }
                    Section {
                        Button { managingCategories = true } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "slider.horizontal.3").font(.system(size: 11))
                                Text("管理分类…").font(.system(size: 11))
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10).padding(.vertical, 9)
                            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain).help("新建、重命名和删除分类")
                        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 10, trailing: 4))
                        ForEach(categories, id: \.self) { category in
                            Label(category, systemImage: "folder").tag("分类:" + category)
                        }
                    } header: {
                        Text("分类")
                    }
                }.listStyle(.sidebar)
                VStack(alignment: .leading, spacing: 12) {
                    Label("仅存储在此设备", systemImage: "internaldrive").font(.caption).foregroundStyle(.secondary)
                    HStack { Button("导入备份") { store.importFile() }; Button("导出备份") { store.exportFile() } }.font(.caption)
                }.padding(16)
            }.navigationSplitViewColumnWidth(min: 205, ideal: 220, max: 270)
        } content: {
            VStack(alignment: .leading, spacing: 15) {
                HStack { VStack(alignment: .leading, spacing: 7) { Text(filter.replacingOccurrences(of: "分类:", with: "")).font(.title2.bold()); Text("\(filtered.count) 条提示词，让好想法有迹可循。").font(.caption).foregroundStyle(.secondary) }; Spacer(); Picker("排序", selection: $sort) { Text("最近更新").tag(0); Text("按名称").tag(1); Text("最多使用").tag(2) }.labelsHidden().frame(width: 100) }.padding(.horizontal, 20).padding(.top, 20)
                List(selection: $selected) {
                    ForEach(filtered) { p in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Text(p.category).font(.caption).foregroundStyle(Color.accentColor); Spacer(); if p.favorite { Image(systemName: "star.fill").foregroundStyle(.orange).font(.caption) } }
                            Text(p.title).font(.headline).lineLimit(2)
                            Text(p.content).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                            HStack { Text(p.tags.map { "#\($0)" }.joined(separator: "  ")).lineLimit(1); Spacer(); Text(String(p.updated.prefix(10))) }.font(.system(size: 10)).foregroundStyle(.tertiary)
                        }.padding(.vertical, 12).tag(p.id)
                        .contextMenu { Button("编辑") { editor = p }; Button("创建副本") { var copy = p; copy.id = UUID().uuidString; copy.title += " · 副本"; copy.versions = []; copy.uses = 0; if store.save(copy) { selected = copy.id } }; Button("删除", role: .destructive) { deletion = p } }
                    }
                    if filtered.isEmpty { VStack(spacing: 12) { Image(systemName: "sparkles").font(.largeTitle); Text(search.isEmpty ? "给好想法一个位置" : "没有找到相关提示词"); Button("新建提示词") { editor = Prompt() } }.foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 70) }
                }.listStyle(.inset)
            }.searchable(text: $search, prompt: "搜索标题、内容和标签").navigationSplitViewColumnWidth(min: 300, ideal: 370, max: 520)
        } detail: {
            if let p = store.library.prompts.first(where: {$0.id == selected}) { Detail(prompt: p) { editor = p } }
            else { VStack(spacing: 18) { Image(systemName: "text.alignleft").font(.system(size: 40, weight: .ultraLight)); Text("留住每一个好想法").font(.title2); Text("选择一条提示词，开始下一次创作。").font(.callout) }.foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("PromptKeep.manageCategories"))) { _ in
            if NSApp.keyWindow != nil && editor == nil { managingCategories = true }
        }
        .sheet(isPresented: $managingCategories) {
            CategoryManager(onRename: { old, new in
                if filter == "分类:" + old { filter = "分类:" + new }
            }, onDelete: { name in
                if filter == "分类:" + name { filter = "分类:未分类" }
            }).quietFocus().buttonStyle(QuietButtonStyle()).environmentObject(store)
        }
        .sheet(item: $editor) { p in Editor(prompt: p) { selected = $0; filter = "全部提示词"; search = "" }.quietFocus().buttonStyle(QuietButtonStyle()).environmentObject(store) }
        .confirmationDialog("删除「\(deletion?.title ?? "")」？此操作无法撤销。", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } })) { Button("删除", role: .destructive) { if let p = deletion { store.remove(p.id); if selected == p.id { selected = nil } }; deletion = nil } }
        .alert("操作未完成", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("好") { store.error = nil } } message: { Text(store.error ?? "") }
        .frame(minWidth: 980, minHeight: 650)
    }
}
@main struct PromptKeepApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup("词笺") { ContentView().quietFocus().buttonStyle(QuietButtonStyle()).environmentObject(store).tint(Color(red: 0.31, green: 0.39, blue: 0.79)) }
        .defaultSize(width: 1180, height: 780)
        .commands { CommandGroup(replacing: .newItem) {
            Button("分类管理…") {
                NotificationCenter.default.post(name: Notification.Name("PromptKeep.manageCategories"), object: nil)
            }
        } ; CommandGroup(after: .importExport) { Button("导入词笺备份…") { store.importFile() }; Button("导出词笺备份…") { store.exportFile() } } }
    }
}
