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
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
]]

--- Load validation and content-extraction modules
local validation_path = quarto.utils.resolve_path("_modules/validation.lua")
local validation = require(validation_path)
local content_path = quarto.utils.resolve_path("_modules/content-extraction.lua")
local content = require(content_path)

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
local function include_external(args, _kwargs, _meta, _raw_args, _context)
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

  -- Use validation module to check markdown extension
  if not validation.is_markdown(uri) then
    quarto.log.warning(
      "[external] Only markdown files (.md, .markdown, .qmd) are supported. " ..
      "The file '" .. uri .. "' will not be included."
    )
    return pandoc.Null()
  end

  --- @type string|nil MIME type of the fetched file (unused but returned by fetch)
  --- @type string|nil File contents as string
  local _mt, contents = pandoc.mediabag.fetch(uri)
  if not contents then
    quarto.log.error(
      "[external] Could not open file '" .. uri .. "'. " ..
      "Please check that the file path is correct and the file is accessible."
    )
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

  -- Use content-extraction module to extract specific section if requested
  if section_id then
    local section_blocks = content.extract_section(contents_blocks, section_id, true)
    if section_blocks == nil then
      quarto.log.error(
        "[external] Section '#" .. section_id .. "' not found in '" .. uri .. "'. " ..
        "Please check that the section identifier matches a header in the file."
      )
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
