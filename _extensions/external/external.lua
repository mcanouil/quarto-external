--[[
# MIT License
#
# Copyright (c) 2025 Mickaël Canouil
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
]]

---
--- Checks if a file extension is markdown-related.
---
--- @param url string The file URL or path.
--- @return boolean True if markdown-related, false otherwise.
local function is_markdown_extension(url)
  local markdown_exts = {".md", ".markdown", ".qmd"}
  for _, ext in ipairs(markdown_exts) do
    if url:sub(-#ext):lower() == ext then
      return true
    end
  end
  return false
end

---
--- Includes external content or a section from a file into a Pandoc document.
---
--- @param args table Arguments, where the first element is the file URL (optionally with a section id as a hash fragment).
--- @return table Pandoc blocks of the included content or an error message as a Para block.
function include_external(args, kwargs, meta, raw_args, context)
  local url = pandoc.utils.stringify(args[1])
  local section_id = nil
  local hash_index = url:find('#')
  if hash_index then
    section_id = url:sub(hash_index + 1)
    url = url:sub(1, hash_index - 1)
  end

  if not is_markdown_extension(url) then
    quarto.log.warning("Only markdown files are supported. The file '" .. url .. "' will not be included.")
    return pandoc.Null()
  end

  local mt, contents = pandoc.mediabag.fetch(url)
  if not contents then
    quarto.log.error("Could not open file '" .. url .. "'. Please check the URL or path.")
    return pandoc.Null()
  end

  local contents_blocks = quarto.utils.string_to_blocks(contents)
  if section_id then
    local found = false
    local section_level = nil
    local section_blocks = {}
    for i, block in ipairs(contents_blocks) do
      if block.t == 'Header' and block.identifier == section_id then
        found = true
        section_level = block.level
      end
      if found then
        if block.t == 'Header' and block.level <= section_level and #section_blocks > 0 then
          break
        end
        table.insert(section_blocks, block)
      end
    end
    if #section_blocks == 0 then
      quarto.log.error("Section '" .. section_id .. "' not found in '" .. url .. "'.")
      return pandoc.Null()
    end
    return pandoc.Blocks(section_blocks)
  end
  return contents_blocks
end

return {
  ['external'] = include_external
}
