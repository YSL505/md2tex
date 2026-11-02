-- tblr-filter.lua
-- 把 pandoc 的 Table 节点转成 tabularray 的 tblr 三线表
-- 用法: pandoc input.md -s -o output.tex --template=template.tex --lua-filter=tblr-filter.lua

-- 单元格内容转为 LaTeX（去掉首尾空白）
local function cell_text(cell)
  local s = pandoc.write(pandoc.Pandoc(cell.contents), "latex")
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- pandoc 各版本 caption 结构不同，统一取出
-- 注意: AST 元素是 userdata, 不能用 type() == "table" 判断
local function get_caption(tbl)
  local cap = tbl.caption
  if cap == nil then return "" end
  if cap.long ~= nil then                          -- pandoc >= 2.17: Caption 对象
    if #cap.long == 0 then return "" end
    return pandoc.utils.stringify(cap.long)
  else                                             -- 旧版本: caption 是 inlines 列表
    if #cap == 0 then return "" end
    return pandoc.utils.stringify(pandoc.Inlines(cap))
  end
end

function Table(tbl)
  local ncols = #tbl.colspecs

  -- 按列数自动生成 colspec，每列都是 X[c,m]（居中、垂直居中、自动折行）
  local colspec = string.rep("X[c,m]", ncols)

  local lines = {}
  local function emit_row(row)
    local cells = {}
    for _, c in ipairs(row.cells) do
      cells[#cells + 1] = cell_text(c)
    end
    lines[#lines + 1] = table.concat(cells, " & ") .. [[ \\]]
  end

  -- 主表头（取第一行）
  if tbl.head and tbl.head.rows and #tbl.head.rows > 0 then
    emit_row(tbl.head.rows[1])
  end

  -- 表体：pandoc 的结构是 bodies 列表，每个 body 里又分 head/body/foot 三段
  if tbl.bodies then
    for _, body in ipairs(tbl.bodies) do
      if body.head then
        for _, row in ipairs(body.head) do emit_row(row) end
      end
      if body.body then
        for _, row in ipairs(body.body) do emit_row(row) end
      end
      if body.foot then
        for _, row in ipairs(body.foot) do emit_row(row) end
      end
    end
  end

  -- 可选：有 caption 就生成 \caption，没有则省略
  local caption = get_caption(tbl)
  local caption_line = ""
  if caption ~= "" then
    caption_line = "  \\caption{" .. caption .. "}\n"
  end

  local latex = string.format([[
\begin{table}[htbp!]
  \centering
%s  \begin{tblr}{
    colspec={%s},
    hline{1}={1pt},
    hline{2}={0.5pt},
    hline{Z}={1pt}
  }
%s
  \end{tblr}
\end{table}]],
    caption_line, colspec, table.concat(lines, "\n"))

  return pandoc.RawBlock("latex", latex)
end
