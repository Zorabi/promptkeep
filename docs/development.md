# 开发说明

## 构建

运行 `./scripts/build.sh`，脚本使用本机 Xcode 工具链生成 Apple 芯片应用，最低部署目标为 macOS 13。应用标识为 `dongx.promptkeep`，作者及版权为 dongx。当前使用临时签名，未经过 Apple 公证；正式分发前需要另行配置开发者签名及公证。

`Sources/Models.swift` 定义数据模型及分类操作，`Sources/PromptKeep.swift` 包含 SwiftUI 界面和本地 JSON 存储，`scripts/make-icon.swift` 生成图标，`Assets/` 保存生成资源。

## 数据

资料库位于 `~/Library/Application Support/dongx.promptkeep/library.json`，采用原子写入。修改前应通过应用导出备份。个人资料和迁移备份不得加入源码分发包。

## PromptFlow 迁移

1. 在 PromptFlow 提示词列表的「… → 导出」中，选择全部记录及 JSON 完整备份。
2. 转换格式：

   ```sh
   python3 scripts/convert-promptflow.py /path/to/promptflow.json /path/to/promptkeep.json
   ```

3. 在 PromptKeep 中点击「导入备份」，选择转换后的文件。

转换保留标题、正文、标签、分类、置顶状态、使用次数和更新时间；描述转为使用笔记。原 ID 加来源前缀，重复导入时可去重。当前转换器不处理图片或生成结果附件，遇到此类数据会中止并提示，原始备份应保留。

本次迁移来源为 PromptFlow 1.4.0 导出的 1.0.0 格式的 JSON 备份，共 7 条提示词，未包含图片或生成结果附件。原始数据仍保留在 PromptFlow 中。

## 验证

```sh
./scripts/build.sh
codesign --verify --deep --strict build/词笺.app
```

以上命令仅验证编译和签名完整性。界面行为需要手动检查：新建与保存、搜索与分类、变量填充与复制、版本恢复、导入去重及导出后再次导入。浅色与深色模式下分别检查鼠标、键盘导航和输入控件状态。

分类数据兼容与联动验证：

```sh
mkdir -p build/tests
xcrun swiftc Sources/Models.swift tests/CategoryTests.swift -o build/tests/category-tests
build/tests/category-tests
```

## 应用名称

中文显示名称为「词笺」，内部项目名为 PromptKeep。包标识及数据目录保持不变，升级无需迁移资料库。

## 宣传素材

运行 `xcrun swift scripts/make-promo.swift` 生成 `docs/images/` 下的横版介绍图、竖版海报与分享封面。素材由矢量绘制的界面示意构成，不包含个人提示词或截图，署名为 dongx。

宣传图当前使用与本机应用一致的橙色系统强调色（sRGB `#F7821B`）。应用控件会受 macOS 强调色设置影响，制作新素材时应先核对实际界面。
