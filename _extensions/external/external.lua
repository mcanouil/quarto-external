--- @module external
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil

--- Extension name constant
local EXTENSION_NAME = 'external'

--- Load utils, validation, content-extraction and header-utils modules
local utils = require(quarto.utils.resolve_path('_modules/utils.lua'):gsub('%.lua$', ''))
local validation = require(quarto.utils.resolve_path('_modules/validation.lua'):gsub('%.lua$', ''))
local content = require(quarto.utils.resolve_path('_modules/content-extraction.lua'):gsub('%.lua$', ''))
local header_utils = require(quarto.utils.resolve_path('_modules/header-utils.lua'):gsub('%.lua$', ''))

--- Includes external content or a section/div from a file into a Pandoc document.
--- Supports including entire markdown files, specific sections identified by header IDs,
--- or divs identified by their IDs.
--- The URI can contain a hash fragment (#id) to include only that section or div.
--- For .qmd files, uses Quarto's string_to_blocks parser.
--- For other markdown files, uses Pandoc's reader with shortcode escaping.
---
--- @param args table Arguments array where first element is the file URI (with optional #id)
--- @param kwargs table Named keyword arguments (shift-heading-level-by, shift)
--- @param _meta table Document metadata (unused)
--- @param _raw_args table Raw arguments (unused)
--- @param _context table Context information (unused)
--- @return table Included content blocks or pandoc.Null() on error
--- @usage {{< external path/to/file.md#section-id >}}
--- @usage {{< external path/to/file.md#div-id >}}
local function include_external(args, kwargs, _meta, _raw_args, _context)
  --- @type string File URI to include
  local uri = pandoc.utils.stringify(args[1])
  --- @type string|nil Optional section or div identifier from hash fragment
  local element_id = nil
  --- @type integer|nil Position of hash character in URI
  local hash_index = uri:find('#')
  if hash_index then
    element_id = uri:sub(hash_index + 1)
    uri = uri:sub(1, hash_index - 1)
  end

  --- @type integer|nil Heading level shift amount
  local shift = nil
  --- @type string Raw shift value from kwargs
  local shift_value = pandoc.utils.stringify(kwargs['shift-heading-level-by'] or kwargs['shift'] or '')
  if shift_value ~= '' then
    shift = tonumber(shift_value)
    if shift == nil then
      utils.log_warning(
        EXTENSION_NAME,
        'Invalid shift-heading-level-by value \'' .. shift_value .. '\'. ' ..
        'Expected an integer. Headings will not be shifted.'
      )
    end
  end

  -- Use validation module to check markdown extension
  if not validation.is_markdown(uri) then
    utils.log_warning(
      EXTENSION_NAME,
      'Only markdown files (.md, .markdown, .qmd) are supported. ' ..
      'The file \'' .. uri .. '\' will not be included.'
    )
    return pandoc.Null()
  end

  --- @type string|nil MIME type of the fetched file (unused but returned by fetch)
  --- @type string|nil File contents as string
  local _mt, contents = pandoc.mediabag.fetch(uri)
  if not contents then
    utils.log_error(
      EXTENSION_NAME,
      'Could not open file \'' .. uri .. '\'. ' ..
      'Please check that the file path is correct and the file is accessible.'
    )
    return pandoc.Null()
  end

  --- @type table Pandoc blocks parsed from file contents
  local contents_blocks

  -- If element_id is provided, strip YAML frontmatter before parsing
  if element_id then
    --- @type string Content without YAML frontmatter
    local content_without_yaml = contents
    local yaml_start = content_without_yaml:match('^%s*%-%-%-')
    if yaml_start then
      local _, yaml_end = content_without_yaml:find('\n%-%-%-%s*\n', 1, false)
      if yaml_end then
        content_without_yaml = content_without_yaml:sub(yaml_end + 1)
      end
    end

    if uri:lower():match('%.qmd$') then
      contents_blocks = quarto.utils.string_to_blocks(content_without_yaml)
    else
      content_without_yaml = content_without_yaml:gsub('({{<.-[ \t]>}})', '{%1}')
      contents_blocks = pandoc.read(content_without_yaml).blocks
    end
  else
    if uri:lower():match('%.qmd$') then
      contents_blocks = quarto.utils.string_to_blocks(contents)
    else
      contents = contents:gsub('({{<.-[ \t]>}})', '{%1}')
      contents_blocks = pandoc.read(contents).blocks
    end
  end

  if element_id then
    local section_blocks = content.extract_section(contents_blocks, element_id, true)
    if section_blocks then
      if shift then
        section_blocks = header_utils.shift_headers(section_blocks, shift)
      end
      return pandoc.Blocks(section_blocks)
    end

    local div_blocks = content.extract_div(contents_blocks, element_id, false)
    if div_blocks then
      if shift then
        div_blocks = header_utils.shift_headers(div_blocks, shift)
      end
      return pandoc.Blocks(div_blocks)
    end

    utils.log_error(
      EXTENSION_NAME,
      'Section or div \'#' .. element_id .. '\' not found in \'' .. uri .. '\'. ' ..
      'Please check that the identifier matches a header or div in the file.'
    )
    return pandoc.Null()
  end

  if shift then
    contents_blocks = header_utils.shift_headers(contents_blocks, shift)
  end
  return contents_blocks
end

--- Module export table.
--- Defines the shortcode available to Quarto for including external content.
--- @type table<string, function>
return {
  ['external'] = include_external
}
