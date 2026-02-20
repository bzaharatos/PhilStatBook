-- filters/latex_to_quarto.lua
-- Runs during Quarto render (Pandoc stage). We will also use it during tex->qmd conversion.

local function strip_ext(path)
  return path:gsub("%.[^./\\]+$", "")
end

local function sanitize_id(id)
  if not id or id == "" then return id end
  return id:gsub(":", "-")
end

local function ensure_prefix(id, prefix)
  if not id or id == "" then return id end
  if id:match("^" .. prefix) then return id end
  return prefix .. id
end

-- 1) Normalize images:
--    - Make image src extensionless so Quarto can pick .svg for html and .pdf for pdf.
--    - Keep IDs consistent (fig-...).
function Image(el)
  if el.src and el.src ~= "" then
    el.src = strip_ext(el.src)
  end

  local id = sanitize_id(el.attr.identifier)
  if id and id ~= "" then
    id = id:gsub("^plot%-", "")       -- optional: drop plot- prefix if you use it
    id = ensure_prefix(id, "fig-")
    el.attr.identifier = id
  end

  return el
end

-- 2) Turn:
--    BlockQuote + following flushright attribution paragraph
--    into a Div {.chapquote} containing quote + attribution div.
function Pandoc(doc)
  local blocks = doc.blocks
  local out = pandoc.List:new()

  local i = 1
  while i <= #blocks do
    local b = blocks[i]

    if b.t == "BlockQuote" and i < #blocks then
      local nxt = blocks[i+1]

      -- Try to recognize a "flushright attribution" that came through as a Para
      if nxt.t == "Para" then
        local txt = pandoc.utils.stringify(nxt)

        -- We emitted "— " in preprocess; keep this match simple.
        if txt:match("^%s*—%s+") then
          local attr_div = pandoc.Div({ nxt }, pandoc.Attr("", { "attribution" }))
          local chap = pandoc.Div({ b, attr_div }, pandoc.Attr("", { "chapquote" }))
          out:insert(chap)
          i = i + 2
        else
          out:insert(b)
          i = i + 1
        end
      else
        out:insert(b)
        i = i + 1
      end
    else
      out:insert(b)
      i = i + 1
    end
  end

  doc.blocks = out
  return doc
end


-- Convert illegal nesting: $$ \begin{align*} ... \end{align*} $$
-- into: $$ \begin{aligned} ... \end{aligned} $$
function Math(el)
  if el.mathtype == "DisplayMath" then
    local t = el.text

    -- align* -> aligned
    if t:match("\\begin%s*%{align%*%}") then
      t = t:gsub("\\begin%s*%{align%*%}", "\\begin{aligned}")
      t = t:gsub("\\end%s*%{align%*%}", "\\end{aligned}")
      el.text = t
      return el
    end

    -- optional: handle align (numbered) similarly, but be aware you lose numbering semantics
    -- if t:match("\\begin%s*%{align%}") then
    --   t = t:gsub("\\begin%s*%{align%}", "\\begin{aligned}")
    --   t = t:gsub("\\end%s*%{align%}", "\\end{aligned}")
    --   el.text = t
    --   return el
    -- end
  end

  return el
end

function Math(el)
  if el.mathtype == "DisplayMath" then
    local t = el.text

    -- 1) align* -> aligned (your previous fix)
    if t:match("\\begin%s*%{align%*%}") then
      t = t:gsub("\\begin%s*%{align%*%}", "\\begin{aligned}")
      t = t:gsub("\\end%s*%{align%*%}", "\\end{aligned}")
      el.text = t
      return el
    end

    -- 2) Remove equation/equation* wrappers inside display math
    if t:match("\\begin%s*%{equation%*?%}") then
      t = t:gsub("\\begin%s*%{equation%*?%}%s*", "")
      t = t:gsub("%s*\\end%s*%{equation%*?%}%s*", "")
      el.text = t
      return el
    end
  end

  return el
end


function DefinitionList(el)
  -- el.content is a list of entries; each entry = { term_inlines, def_blocks_list }
  if #el.content > 0 then
    local first_entry = el.content[1]
    local term_inlines = first_entry[1]
    local term_text = pandoc.utils.stringify(term_inlines)

    -- Match "Argument #1", "Argument #2", etc.
    if term_text:match("^%s*Argument%s*#%d+%s*$") then
      return pandoc.Div({ el }, pandoc.Attr("", { "argument" }))
    end
  end
  return el
end


