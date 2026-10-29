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
// Keep the native search field and its keyboard behavior; suppress only its focus ring.
struct SearchFocusAppearance: NSViewRepresentable {
    final class AnchorView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyAppearance()
            DispatchQueue.main.async { [weak self] in self?.applyAppearance() }
        }
        func applyAppearance() {
            guard let window else { return }
            func configure(_ view: NSView) {
                if let search = view as? NSSearchField,
                   search.placeholderString == "搜索标题、内容和标签" {
                    search.focusRingType = .none
                }
                for child in view.subviews { configure(child) }
            }
            if let content = window.contentView { configure(content) }
            for item in window.toolbar?.items ?? [] {
                if let searchItem = item as? NSSearchToolbarItem { configure(searchItem.searchField) }
                else if let view = item.view { configure(view) }
            }
        }
    }
    func makeNSView(context: Context) -> AnchorView { AnchorView() }
    func updateNSView(_ view: AnchorView, context: Context) {
        DispatchQueue.main.async { [weak view] in view?.applyAppearance() }
    }
}
enum AppColors {
    static let action = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 1, green: 0.65, blue: 0.36, alpha: 1)
            : NSColor(srgbRed: 0.72, green: 0.28, blue: 0.035, alpha: 1)
    })
}
struct QuietButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        ButtonSurface(configuration: configuration, prominent: prominent)
    }
    private struct ButtonSurface: View {
        let configuration: ButtonStyle.Configuration
        let prominent: Bool
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.isFocused) private var isFocused
        @Environment(\.colorScheme) private var colorScheme
        @State private var hovered = false
        private var active: Bool { configuration.isPressed || hovered || isFocused }
        var body: some View {
            configuration.label
                .padding(.horizontal, 10).padding(.vertical, 6)
                .foregroundStyle(!isEnabled ? Color.secondary : prominent ? (colorScheme == .dark ? Color.black : Color.white) : AppColors.action)
                .background(!isEnabled ? Color.primary.opacity(0.06) : prominent ? AppColors.action.opacity(configuration.isPressed ? 0.75 : active ? 0.88 : 1) : AppColors.action.opacity(active ? 0.22 : 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .onHover { hovered = $0 }
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
            Text("使用 {{变量名}} 创建可填充的模板").font(.system(size: 13)).foregroundStyle(.secondary)
            TextEditor(text: $prompt.content).font(.system(size: 16)).padding(8).background(.background).clipShape(RoundedRectangle(cornerRadius: 8)).frame(minHeight: 200)
            Text("使用笔记（可选）").font(.headline)
            TextEditor(text: $prompt.result).font(.system(size: 16)).padding(8).background(.background).clipShape(RoundedRectangle(cornerRadius: 8)).frame(height: 115)
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
    @State private var section = 0
    @State private var values: [String: String] = [:]
    @State private var copied = false
    @State private var previewExpanded = false
    @State private var previewHovered = false
    @FocusState private var previewFocused: Bool
    @State private var restore: Revision?
    var draft: TextDraft { store.draft(for: prompt) }
    var dirty: Bool { store.drafts[prompt.id] != nil }
    func binding(_ key: WritableKeyPath<TextDraft, String>) -> Binding<String> {
        Binding(get: { store.draft(for: prompt)[keyPath: key] }, set: { value in
            var next = store.draft(for: prompt); next[keyPath: key] = value
            store.updateDraft(id: prompt.id, next); copied = false
        })
    }
    var variables: [String] {
        let regex = try! NSRegularExpression(pattern: #"\{\{([^{}]+)\}\}"#)
        let text = draft.content as NSString
        var seen = Set<String>()
        return regex.matches(in: draft.content, range: NSRange(location: 0, length: text.length)).map { text.substring(with: $0.range(at: 1)) }.filter { seen.insert($0).inserted }
    }
    var filled: String { variables.reduce(draft.content) { text, key in
        let value = values[key] ?? ""
        return value.isEmpty ? text : text.replacingOccurrences(of: "{{\(key)}}", with: value)
    } }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Menu {
                    ForEach(["未分类"] + store.categories, id: \.self) { category in
                        Button(category) { _ = store.organize(ids: [prompt.id], category: category) }
                    }
                } label: { Label(prompt.category, systemImage: "folder") }.menuStyle(.borderlessButton).fixedSize()
                Spacer()
                Button { var p = prompt; p.favorite.toggle(); store.save(p) } label: {
                    Image(systemName: prompt.favorite ? "star.fill" : "star")
                }.help("收藏")
            }
            TextField("提示词标题", text: binding(\.title), axis: .vertical)
                .font(.system(size: 27, weight: .bold, design: .rounded)).textFieldStyle(.plain)
                .padding(8).background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 7))
            HStack {
                Text(prompt.tags.map { "#\($0)" }.joined(separator: "   ")).foregroundStyle(.secondary).font(.system(size: 13))
                Spacer()
                Menu("标签") {
                    ForEach(store.tags, id: \.self) { tag in
                        Toggle(tag, isOn: Binding(get: { prompt.tags.contains(tag) }, set: { on in
                            var p = prompt
                            if on { if !p.tags.contains(tag) { p.tags.append(tag) } } else { p.tags.removeAll { $0 == tag } }
                            store.save(p)
                        }))
                    }
                }.menuStyle(.borderlessButton).font(.system(size: 13)).fixedSize()
            }
            Picker("内容", selection: $section) {
                Text("提示词").tag(0); Text("使用笔记").tag(1); Text("历史版本 · \(prompt.versions.count)").tag(2)
            }.pickerStyle(.segmented)
            if section == 2 {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if prompt.versions.isEmpty { Text("保存修改后，旧正文和笔记会保留在这里。").foregroundStyle(.secondary).padding(.top, 30) }
                        ForEach(Array(prompt.versions.enumerated().reversed()), id: \.offset) { _, version in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(version.date.prefix(10)).font(.system(size: 13)).foregroundStyle(.secondary)
                                Text(version.content).lineLimit(7).textSelection(.enabled)
                                Button("恢复此版本") { restore = version }.disabled(dirty)
                            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                                .background(.quaternary.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            } else {
                Text(section == 0 ? "直接编辑提示词 · 使用 {{变量名}} 创建模板" : "直接记录适用场景、使用方法和改进想法")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                TextEditor(text: binding(section == 0 ? \.content : \.result))
                    .font(.system(size: 16)).lineSpacing(7).padding(12)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                    .frame(minHeight: 180)
                if section == 0 && !variables.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Button {
                            previewExpanded.toggle()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: previewExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 10, weight: .semibold)).frame(width: 12)
                                Text("模板变量与复制预览").font(.system(size: 13, weight: .medium))
                                Text("\(variables.count)").font(.system(size: 12)).foregroundStyle(.secondary)
                                Spacer()
                            }.padding(12).contentShape(Rectangle())
                        }.buttonStyle(.plain).focused($previewFocused)
                            .onHover { previewHovered = $0 }
                            .background(Color.primary.opacity(previewFocused || previewHovered ? 0.06 : 0))
                            .accessibilityLabel(previewExpanded ? "收起模板变量与复制预览" : "展开模板变量与复制预览")
                        if previewExpanded {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(variables, id: \.self) { key in
                                        HStack {
                                            Text(key).font(.system(size: 13)).frame(width: 75, alignment: .leading)
                                            TextField("输入\(key)", text: Binding(get: { values[key] ?? "" }, set: { values[key] = $0 }))
                                                .textFieldStyle(.roundedBorder)
                                        }
                                    }
                                    Text(filled).font(.system(size: 13)).foregroundStyle(.secondary)
                                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                }.padding(.horizontal, 12).padding(.bottom, 12)
                            }.frame(height: 180)
                        }
                    }.background(Color.accentColor.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Label(dirty ? (draft.canSave ? "有未保存修改" : "标题和正文不能为空") : "已保存", systemImage: dirty ? "pencil.circle" : "checkmark.circle")
                    .font(.system(size: 13)).foregroundStyle(dirty ? Color.orange : Color.secondary)
                HStack(spacing: 10) {
                    if section != 2 {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(section == 0 ? filled : draft.result, forType: .string)
                    var p = prompt; p.uses += 1; store.save(p); copied = true
                } label: {
                    Label(copied ? "已复制" : "复制\(section == 0 ? "提示词" : "笔记")", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .padding(.horizontal, 3).padding(.vertical, 2)
                }.buttonStyle(QuietButtonStyle(prominent: true))
                    .disabled(section == 0 ? draft.content.isEmpty : draft.result.isEmpty)
                    .help("复制当前内容；未保存的修改会保留为草稿")
                    }
                    Spacer(minLength: 8)
                    if dirty { Button("取消修改") { store.discardDraft(prompt.id) } }
                    Button("保存") { store.saveDraft(prompt.id) }.keyboardShortcut("s")
                        .buttonStyle(QuietButtonStyle(prominent: true)).disabled(!dirty || !draft.canSave)
                }
            }
        }.padding(28).frame(minWidth: 360)
        .onChange(of: prompt.id) { _ in values = [:]; section = 0; copied = false; previewExpanded = false }
        .onChange(of: values) { _ in copied = false }
        .confirmationDialog("恢复此版本？当前内容会保留为历史版本。", isPresented: Binding(get: { restore != nil }, set: { if !$0 { restore = nil } })) {
            Button("恢复版本") {
                if let v = restore { var p = prompt; p.content = v.content; p.result = v.result; store.save(p); section = 0 }
                restore = nil
            }
        }
    }
}
struct CategoryManager: View {
    var isTag = false
    private var kind: String { isTag ? "标签" : "分类" }
    private var names: [String] { isTag ? store.tags : store.categories }
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
                    Text("\(kind)管理").font(.title2.bold())
                    Text(isTag ? "一个提示词可以添加多个标签。" : "先建分类，再慢慢收集好用的提示词。").font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            HStack {
                TextField(editing == nil ? "新\(kind)名称" : "新的\(kind)名称", text: $name).textFieldStyle(.roundedBorder)
                    .onSubmit { save() }
                if editing != nil { Button("取消重命名") { editing = nil; name = "" } }
                Button(editing == nil ? "添加\(kind)" : "保存名称") { save() }
                    .buttonStyle(QuietButtonStyle(prominent: true))
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            ScrollView {
                VStack(spacing: 8) {
                    if !isTag { HStack {
                        Label("未分类", systemImage: "tray")
                        Spacer()
                        Text("系统分类").font(.system(size: 13)).foregroundStyle(.secondary)
                    }.padding(12) }
                    ForEach(names, id: \.self) { category in
                        HStack {
                            Label(category, systemImage: isTag ? "tag" : "folder")
                            Text("\(store.library.prompts.filter { isTag ? $0.tags.contains(category) : $0.category == category }.count) 条").font(.system(size: 13)).foregroundStyle(.secondary)
                            Spacer()
                            Button("重命名") { editing = category; name = category }
                            Button("删除", role: .destructive) { deleting = category }
                        }.padding(12).background(Color.primary.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    if names.isEmpty { Text("还没有自定义\(kind)，添加后会显示在侧边栏。").font(.callout).foregroundStyle(.secondary).padding(24) }
                }
            }
            Text(isTag ? "删除标签只会移除关联，提示词和其他标签都会保留。" : "删除分类不会删除提示词，内容会移入「未分类」。").font(.system(size: 13)).foregroundStyle(.secondary)
        }.padding(24).frame(width: 580, height: 430)
        .confirmationDialog("删除「\(deleting ?? "")」\(kind)？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("删除\(kind)", role: .destructive) {
                if let category = deleting, (isTag ? store.deleteTag(category) : store.deleteCategory(category)) {
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
        if (isTag ? store.setTag(trimmed, replacing: editing) : store.setCategory(trimmed, replacing: editing)) {
            if let editing { onRename(editing, trimmed) }
            editing = nil; name = ""
        }
    }
}
extension UTType {
    static let promptkeepRecord = UTType(exportedAs: "dongx.promptkeep.record")
}
struct OrganizationRow: View {
    var name: String
    var isTag = false
    var selected = false
    var select: () -> Void
    var onDrop: ([String]) -> Bool
    @State private var targeted = false
    @State private var hovered = false
    @FocusState private var focused: Bool
    var body: some View {
        Button(action: select) {
            Label(name, systemImage: isTag ? "tag" : "folder")
                .font(.system(size: 14)).frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 8).contentShape(Rectangle())
        }.buttonStyle(.plain).focused($focused)
            .background((selected || focused || hovered) ? Color.primary.opacity(selected ? 0.09 : 0.045) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
            .onHover { hovered = $0 }
            .background(targeted ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .onDrop(of: [.promptkeepRecord], isTargeted: $targeted) { providers in
                guard !providers.isEmpty else { return false }
                var ids: [String] = []
                var remaining = providers.count
                var valid = true
                for provider in providers {
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.promptkeepRecord.identifier) { data, _ in
                        let id = data.flatMap { String(data: $0, encoding: .utf8) }
                        DispatchQueue.main.async {
                            if let id { ids.append(id) } else { valid = false }
                            remaining -= 1
                            if remaining == 0 && valid { _ = onDrop(ids) }
                        }
                    }
                }
                return true
            }
            .help(isTag ? "拖入提示词，追加此标签" : "拖入提示词，移到此分类")
    }
}
struct PromptListRow: View {
    let prompt: Prompt
    let draft: TextDraft?
    private var summary: String {
        let text = draft?.content ?? prompt.content
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "#*>- \t")) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(draft?.title.isEmpty == false ? draft!.title : prompt.title)
                    .font(.system(size: 16, weight: .semibold)).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if prompt.favorite {
                    Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(AppColors.action)
                        .accessibilityLabel("已收藏")
                }
                if draft != nil {
                    Label { Text("未保存") } icon: { Image(systemName: "circle.fill").font(.system(size: 5)) }
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(AppColors.action)
                        .fixedSize().help("这条提示词有未保存的修改")
                }
            }
            Text(summary.isEmpty ? "暂无内容" : summary)
                .font(.system(size: 14)).foregroundStyle(.secondary)
                .lineSpacing(4).lineLimit(2, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 7) {
                Text(prompt.category).foregroundStyle(AppColors.action).lineLimit(1)
                if !prompt.tags.isEmpty {
                    Text(prompt.tags.prefix(2).map { "#" + $0 }.joined(separator: "  ") + (prompt.tags.count > 2 ? "  +\(prompt.tags.count - 2)" : ""))
                        .foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(String(prompt.updated.prefix(10))).foregroundStyle(.secondary).fixedSize()
            }.font(.system(size: 12))
        }.padding(.vertical, 12).padding(.horizontal, 4)
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
    @State private var managingTags = false
    @FocusState private var focusedNavigation: String?
    @State private var hoveredNavigation: String?
    var categories: [String] { ["未分类"] + store.categories }
    var filtered: [Prompt] {
        store.library.prompts.filter { p in
            (filter == "全部提示词" || filter == "我的收藏" && p.favorite || filter == "最近使用" && p.uses > 0 || filter == "分类:" + p.category || filter.hasPrefix("标签:") && p.tags.contains(String(filter.dropFirst(3)))) && (search.isEmpty || ([p.title, p.content, p.result] + p.tags).joined(separator: " ").localizedCaseInsensitiveContains(search))
        }.sorted { a,b in sort == 1 ? a.title.localizedCompare(b.title) == .orderedAscending : sort == 2 ? a.uses > b.uses : a.updated > b.updated }
    }
    private func managementButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "slider.horizontal.3").font(.system(size: 11))
                Text(title).font(.system(size: 13, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
            }.foregroundStyle(AppColors.action).padding(.horizontal, 10).padding(.vertical, 9)
                .background(AppColors.action.opacity(focusedNavigation == title || hoveredNavigation == title ? 0.22 : 0.12), in: RoundedRectangle(cornerRadius: 7))
        }.buttonStyle(.plain).focused($focusedNavigation, equals: title)
            .onHover { hoveredNavigation = $0 ? title : nil }.padding(.bottom, 6)
    }
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) { Image(systemName: "text.book.closed.fill").font(.title).foregroundStyle(Color.accentColor); VStack(alignment: .leading) { Text("词笺").font(.headline); Text("你的私人提示词工作台").font(.system(size: 12)).foregroundStyle(.secondary) } }.padding(18)
                Button { editor = Prompt() } label: { Label("新建提示词", systemImage: "plus").frame(maxWidth: .infinity).padding(5) }.buttonStyle(QuietButtonStyle(prominent: true)).padding(.horizontal, 16).padding(.bottom, 16).keyboardShortcut("n")
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("资料库").font(.system(size: 13)).foregroundStyle(.secondary).padding(.horizontal, 12).padding(.bottom, 4)
                        ForEach([("全部提示词", "square.grid.2x2"), ("我的收藏", "star"), ("最近使用", "clock")], id: \.0) { title, icon in
                            Button { filter = title } label: {
                                Label(title, systemImage: icon).font(.system(size: 14)).frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12).padding(.vertical, 8).contentShape(Rectangle())
                            }.buttonStyle(.plain).focused($focusedNavigation, equals: title)
                            .onHover { hoveredNavigation = $0 ? title : nil }
                            .background(filter == title || focusedNavigation == title || hoveredNavigation == title ? Color.primary.opacity(filter == title ? 0.09 : 0.045) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                        }
                        Text("分类").font(.system(size: 13)).foregroundStyle(.secondary).padding(.horizontal, 12).padding(.top, 18).padding(.bottom, 4)
                        managementButton("管理分类…") { managingCategories = true }
                        ForEach(categories, id: \.self) { category in
                            OrganizationRow(name: category, selected: filter == "分类:" + category, select: { filter = "分类:" + category }) {
                                store.organize(ids: $0, category: category)
                            }
                        }
                        Text("标签").font(.system(size: 13)).foregroundStyle(.secondary).padding(.horizontal, 12).padding(.top, 18).padding(.bottom, 4)
                        managementButton("管理标签…") { managingTags = true }
                        ForEach(store.tags, id: \.self) { tag in
                            OrganizationRow(name: tag, isTag: true, selected: filter == "标签:" + tag, select: { filter = "标签:" + tag }) {
                                store.organize(ids: $0, tag: tag)
                            }
                        }
                    }.padding(.horizontal, 10).padding(.vertical, 8)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Label("仅存储在此设备", systemImage: "internaldrive").font(.system(size: 13)).foregroundStyle(.secondary)
                    HStack { Button("导入备份") { store.importFile() }; Button("导出备份") { store.exportFile() } }.font(.system(size: 13))
                }.padding(16)
            }.navigationSplitViewColumnWidth(min: 220, ideal: 235, max: 280)
        } content: {
            VStack(alignment: .leading, spacing: 15) {
                HStack { VStack(alignment: .leading, spacing: 7) { Text(filter.hasPrefix("分类:") || filter.hasPrefix("标签:") ? String(filter.dropFirst(3)) : filter).font(.title2.bold()); Text("\(filtered.count) 条提示词").font(.system(size: 13)).foregroundStyle(.secondary) }; Spacer(); Picker("排序", selection: $sort) { Text("最近更新").tag(0); Text("按名称").tag(1); Text("最多使用").tag(2) }.labelsHidden().frame(width: 100) }.padding(.horizontal, 20).padding(.top, 20)
                List(selection: $selected) {
                    ForEach(filtered) { p in
                        PromptListRow(prompt: p, draft: store.drafts[p.id]).tag(p.id)
                        .onDrag {
                            NSItemProvider(item: Data(p.id.utf8) as NSData, typeIdentifier: UTType.promptkeepRecord.identifier)
                        }
                        .contextMenu { Button("编辑") { selected = p.id }; Menu("移到分类") {
                            ForEach(categories, id: \.self) { category in Button(category) { _ = store.organize(ids: [p.id], category: category) } }
                        }; Menu("添加标签") {
                            ForEach(store.tags, id: \.self) { tag in Button(tag) { _ = store.organize(ids: [p.id], tag: tag) } }
                        }; Button("创建副本") { var copy = p; copy.id = UUID().uuidString; copy.title += " · 副本"; copy.versions = []; copy.uses = 0; if store.save(copy) { selected = copy.id } }; Button("删除", role: .destructive) { deletion = p } }
                    }
                    if filtered.isEmpty { VStack(spacing: 12) { Image(systemName: "sparkles").font(.largeTitle); Text(search.isEmpty ? "给好想法一个位置" : "没有找到相关提示词"); Button("新建提示词") { editor = Prompt() } }.foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 70) }
                }.listStyle(.inset)
            }.searchable(text: $search, prompt: "搜索标题、内容和标签").navigationSplitViewColumnWidth(min: 340, ideal: 390, max: 540)
        } detail: {
            if let p = store.library.prompts.first(where: {$0.id == selected}) { Detail(prompt: p) }
            else { VStack(spacing: 18) { Image(systemName: "text.alignleft").font(.system(size: 40, weight: .ultraLight)); Text("留住每一个好想法").font(.title2); Text("选择一条提示词，开始下一次创作。").font(.callout) }.foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .background(SearchFocusAppearance().frame(width: 0, height: 0))
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
        .sheet(isPresented: $managingTags) {
            CategoryManager(isTag: true, onRename: { old, new in
                if filter == "标签:" + old { filter = "标签:" + new }
            }, onDelete: { name in
                if filter == "标签:" + name { filter = "全部提示词" }
            }).quietFocus().buttonStyle(QuietButtonStyle()).environmentObject(store)
        }
        .sheet(item: $editor) { p in Editor(prompt: p) { selected = $0; filter = "全部提示词"; search = "" }.font(.system(size: 14)).quietFocus().buttonStyle(QuietButtonStyle()).environmentObject(store) }
        .confirmationDialog("删除「\(deletion?.title ?? "")」？此操作无法撤销。", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } })) { Button("删除", role: .destructive) { if let p = deletion { store.remove(p.id); if selected == p.id { selected = nil } }; deletion = nil } }
        .alert("操作未完成", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("好") { store.error = nil } } message: { Text(store.error ?? "") }
        .frame(minWidth: 980, minHeight: 650)
    }
}
@main struct PromptKeepApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup("词笺") { ContentView().font(.system(size: 14)).quietFocus().buttonStyle(QuietButtonStyle()).environmentObject(store).tint(AppColors.action) }
        .defaultSize(width: 1180, height: 780)
        .commands { CommandGroup(replacing: .newItem) {
            Button("分类管理…") {
                NotificationCenter.default.post(name: Notification.Name("PromptKeep.manageCategories"), object: nil)
            }
        } ; CommandGroup(after: .importExport) { Button("导入词笺备份…") { store.importFile() }; Button("导出词笺备份…") { store.exportFile() } } }
    }
}
