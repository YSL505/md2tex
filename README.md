# md2tex

一个 Obsidian 桌面端插件：使用本地 Pandoc 将 Markdown 笔记转换为 TeX，并可调用 XeLaTeX 编译为 PDF。

项目源于日常笔记的文档导出与排版需求，在 AI Agent 协助下开发和迭代。

## 功能

- 从命令面板、侧栏按钮或文件右键菜单导出当前笔记。
- 选择仅导出 TeX，或使用 XeLaTeX 连续编译两遍生成 PDF。
- 支持自定义 TeX 模板、Lua 过滤器、工具路径和输出目录。
- 根据 Obsidian 的链接信息，将可解析的附件复制到临时工作目录。
- 保留临时文件与失败日志，便于检查转换和编译问题。

## 环境要求

- Obsidian 桌面端，版本不低于 1.4.0。
- 本地安装 Pandoc；导出 PDF 还需要 XeLaTeX。
- 使用内置中文模板时，需要安装相应中文字体及模板依赖的 LaTeX 宏包。

## 手动安装

1. 下载本仓库，在 Obsidian 库内创建 `.obsidian/plugins/pandoc-export/` 文件夹。
2. 将 `main.js`、`manifest.json`、`versions.json` 和整个 `assets/` 文件夹复制到该目录。
3. 在 Obsidian 中重新加载插件，并在第三方插件设置中启用 **Pandoc Export (TeX → PDF)**。
4. 在插件设置中指定 Pandoc、XeLaTeX 的可执行文件路径；已加入系统 PATH 时可以留空。
5. 打开 Markdown 笔记，通过命令面板或文件右键菜单选择导出。

## 图片与表格

- `assets/template.tex`：文档模板，可按个人字体与版式需求修改。
- `assets/tblr-filter.lua`：将 Markdown 表格转换为 tabularray 的表格环境。
- `assets/figure-filter.lua`：统一独立图片的 LaTeX 排版，支持 Obsidian 图片嵌入与普通 Markdown 图片。

例如：

```markdown
![[图片.png]]
![[附件/带空格的图片.png|300]]
![[图片.png|图片说明]]
![图片说明](images/example.png)
```

独立图片默认使用 `width=\linewidth`；Obsidian 中的尺寸参数不改变其导出宽度。图题默认取不含扩展名的文件名，也可提供图片说明。夹在正文中的图片保持行内排版。

## 使用说明与限制

- 目前仅支持本地文件系统上的 Obsidian 桌面端库。
- PDF 编译依赖本机 LaTeX 环境和模板中的字体、宏包；图片格式也需要被编译器支持。
- TeX 文件中的图片路径相对于临时工作目录。仅导出 TeX 后，如需在其他目录编译，应一并复制相关附件并调整路径。
- 当前仓库包含可供 Obsidian 加载的 JavaScript 插件文件、模板和 Lua 过滤器；未包含 TypeScript 工程或构建脚本。
- `data.json` 是个人配置文件，已通过 `.gitignore` 排除。
