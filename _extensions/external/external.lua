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

--- Checks if a file extension is markdown-related.
--- Determines whether a given URI ends with a markdown file extension.
--- Supported extensions: .md, .markdown, .qmd
---
--- @param uri string The file URI to check
--- @return boolean True if markdown-related, false otherwise
local function is_markdown_extension(uri)
  --- @type string URI converted to lowercase for case-insensitive matching
  local lower_uri = uri:lower()
  --- @type table<integer, string> List of supported markdown file extensions
  local markdown_exts = {'.md', '.markdown', '.qmd'}
  for _, ext in ipairs(markdown_exts) do
    if lower_uri:match('%' .. ext .. '$') then
      return true
    end
  end
  return false
end

--- Includes external content or a section from a file into a Pandoc document.
--- Supports including entire markdown files or specific sections identified by header IDs.
--- The URI can contain a hash fragment (#section-id) to include only that section.
--- For .qmd files, uses Quarto's string_to_blocks parser.
--- For other markdown files, uses Pandoc's reader with shortcode escaping.
---
--- @param args table Arguments array where first element is the file URI (with optional #section-id)
--- @param _kwargs table Named keyword arguments (unused)
--- @param _meta table Document metadata (unused)
--- @param _raw_args table Raw arguments (unused)
--- @param _context table Context information (unused)
--- @return table Included content blocks or pandoc.Null() on error
--- @usage {{< external path/to/file.md#section-id >}}
function include_external(args, _kwargs, _meta, _raw_args, _context)
  --- @type string File URI to include
  local uri = pandoc.utils.stringify(args[1])
  --- @type string|nil Optional section identifier from hash fragment
  local section_id = nil
  --- @type integer|nil Position of hash character in URI
  local hash_index = uri:find('#')
  if hash_index then
    section_id = uri:sub(hash_index + 1)
    uri = uri:sub(1, hash_index - 1)
  end

  if not is_markdown_extension(uri) then
    quarto.log.warning("Only markdown files are supported. The file '" .. uri .. "' will not be included.")
    return pandoc.Null()
  end

  --- @type string|nil MIME type of the fetched file (unused but returned by fetch)
  --- @type string|nil File contents as string
  local _mt, contents = pandoc.mediabag.fetch(uri)
  if not contents then
    quarto.log.error("Could not open file '" .. uri .. "'. Please check the URI.")
    return pandoc.Null()
  end

  --- @type table Pandoc blocks parsed from file contents
  local contents_blocks
  if uri:lower():match('%.qmd$') then
    contents_blocks = quarto.utils.string_to_blocks(contents)
  else
    contents = contents:gsub('({{<.-[ \t]>}})', '{%1}')
    contents_blocks = pandoc.read(contents).blocks
  end
  if section_id then
    --- @type boolean Flag indicating if the target section has been found
    local found = false
    --- @type integer|nil Header level of the target section
    local section_level = nil
    --- @type table<integer, table> Blocks belonging to the target section
    local section_blocks = {}
    for _, block in ipairs(contents_blocks) do
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
      quarto.log.error("Section '" .. section_id .. "' not found in '" .. uri .. "'.")
      return pandoc.Null()
    end
    return pandoc.Blocks(section_blocks)
  end
  return contents_blocks
end

--- Module export table.
--- Defines the shortcode available to Quarto for including external content.
--- @type table<string, function>
return {
  ['external'] = include_external
}
