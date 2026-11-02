-- 将 Obsidian 图片嵌入和独立的 Markdown 图片转换为统一的 LaTeX figure：
--   \begin{figure}
--       \centering
--       \includegraphics[width=\linewidth]{fig-path}
--       \caption{fig-name}
--   \end{figure}
-- 支持 ![[图片.png]]、含空格的路径、|300、|300x200 和 |图片说明。
-- 独立图片统一使用 \linewidth，忽略 Obsidian 中的预览尺寸。
-- Wiki 图片默认以文件名（不含目录和扩展名）为图题；Markdown 图片优先使用 alt。
-- 段落中只有图片时，每张图片生成一个 figure；夹在正文里的图片保持行内。
-- 插件默认的 Markdown reader 即可使用，无需开启 wikilinks 扩展。

if not FORMAT:match("latex") then return {} end

local image_exts = {
  png = true, jpg = true, jpeg = true, gif = true,
  svg = true, pdf = true, bmp = true, webp = true,
}

local function stem(path)
  local base = path:match("([^/\\]+)$") or path
  return (base:gsub("%.%w+$", ""))
end

-- 一次性转义，避免新插入的 LaTeX 命令再被后续替换破坏。
local latex_escapes = {
  ["\\"] = "\\textbackslash{}", ["&"] = "\\&", ["%"] = "\\%",
  ["$"] = "\\$", ["#"] = "\\#", ["_"] = "\\_",
  ["{"] = "\\{", ["}"] = "\\}",
  ["~"] = "\\textasciitilde{}", ["^"] = "\\textasciicircum{}",
}

local function escape_latex(text)
  return (text:gsub("[\\&%%$#_{}~^]", latex_escapes))
end

local function wiki_image(text)
  local path, option = text:match("^(.-)|(.*)$")
  path = path or text
  local ext = path:match("%.(%w+)$")
  if not (ext and image_exts[ext:lower()]) then return nil end

  local caption = stem(path)
  local attributes = {}
  if option then
    local width, height = option:match("^(%d+)x(%d+)$")
    if width then
      attributes.width = width .. "px"
      attributes.height = height .. "px"
    elseif option:match("^%d+$") then
      attributes.width = option .. "px"
    elseif option ~= "" then
      caption = option
    end
  end
  return pandoc.Image({ pandoc.Str(caption) }, path, "", pandoc.Attr("", {}, attributes))
end

local function append_text(out, text)
  local pos = 1
  while pos <= #text do
    local space = text:find(" ", pos, true)
    if not space then
      out[#out + 1] = pandoc.Str(text:sub(pos))
      break
    end
    if space > pos then out[#out + 1] = pandoc.Str(text:sub(pos, space - 1)) end
    out[#out + 1] = pandoc.Space()
    pos = space + 1
  end
end

-- Pandoc 会把 ![[Pasted image.png]] 拆成多个 Str/Space，需合并后匹配。
-- 只扫描普通文本片段，代码、公式、链接等节点保持原样。
local function convert_wikilinks(inlines)
  local out, run = {}, {}
  local function flush()
    if #run == 0 then return end
    local parts = {}
    for _, inline in ipairs(run) do
      parts[#parts + 1] = inline.t == "Space" and " " or inline.text
    end
    local text = table.concat(parts)
    local pos, search = 1, 1
    while true do
      local first = text:find("![[", search, true)
      if not first then break end
      local last = text:find("]]", first + 3, true)
      if not last then break end
      local img = wiki_image(text:sub(first + 3, last - 1))
      if img then
        append_text(out, text:sub(pos, first - 1))
        out[#out + 1] = img
        pos = last + 2
      end
      search = last + 2
    end
    if pos == 1 then
      for _, inline in ipairs(run) do out[#out + 1] = inline end
    else
      append_text(out, text:sub(pos))
    end
    run = {}
  end

  for _, inline in ipairs(inlines) do
    if inline.t == "Str" or inline.t == "Space" then
      run[#run + 1] = inline
    else
      flush()
      out[#out + 1] = inline
    end
  end
  flush()
  return out
end

local function figure_latex(img, caption, identifier)
  -- 复用 Pandoc 对图片路径的 URL 解码和 LaTeX 转义，不沿用其图片包装宏。
  local latex = pandoc.write(pandoc.Pandoc({
    pandoc.Plain({ pandoc.Image({}, img.src) }),
  }), "latex")
  local path = latex:match("\\includegraphics%b[](%b{})")
    or latex:match("\\includegraphics(%b{})")
  assert(path, "无法生成图片的 LaTeX 路径：" .. img.src)
  -- graphicx 的文件名参数不能使用排版用的 \# / \%，改用可展开的字符常量。
  path = path:gsub("\\#", "\\csname c_hash_str\\endcsname ")
    :gsub("\\%%", "\\csname @percentchar\\endcsname ")
  caption = caption or pandoc.utils.stringify(img.caption)
  if caption == "" then caption = stem(img.src) end
  local lines = {
    "\\begin{figure}",
    "    \\centering",
    "    \\includegraphics[width=\\linewidth]" .. path,
    "    \\caption{" .. escape_latex(caption) .. "}",
  }
  if identifier and identifier ~= "" then
    lines[#lines + 1] = "    \\label{" .. identifier .. "}"
  end
  lines[#lines + 1] = "\\end{figure}"
  return pandoc.RawBlock("latex", table.concat(lines, "\n"))
end

-- Pandoc 3 将独立的 Markdown 图片解析为 Figure，而非 Para。
local function convert_figure(fig)
  if #fig.content ~= 1 then return nil end
  local block = fig.content[1]
  if block.t ~= "Plain" and block.t ~= "Para" then return nil end
  if #block.content ~= 1 or block.content[1].t ~= "Image" then return nil end
  local caption = pandoc.utils.stringify(fig.caption.long)
  return figure_latex(block.content[1], caption ~= "" and caption or nil, fig.identifier)
end

local function convert_image_block(block)
  local images = {}
  for _, inline in ipairs(block.content) do
    if inline.t == "Image" then
      images[#images + 1] = inline
    elseif inline.t ~= "Space" and inline.t ~= "SoftBreak" and inline.t ~= "LineBreak" then
      return nil
    end
  end
  if #images == 0 then return nil end
  local figures = {}
  for _, img in ipairs(images) do figures[#figures + 1] = figure_latex(img) end
  return figures
end

-- 剩余行内图片给出默认宽度，避免 Pandoc 3 输出模板未定义的 \pandocbounded。
local function size_inline_image(img)
  if not img.attributes.width and not img.attributes.height then
    img.attributes.width = "100%"
    return img
  end
end

-- 分三遍运行，先识别图片，再替换已有 Figure，最后处理图片段落。
-- 避免先把 Figure 内的 Plain 转成 RawBlock，导致重复嵌套 figure。
return {
  { Inlines = convert_wikilinks },
  { Figure = convert_figure },
  { Image = size_inline_image, Para = convert_image_block, Plain = convert_image_block },
}
