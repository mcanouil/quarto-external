--- @module external
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil

--- Extension name constant
local EXTENSION_NAME = 'external'

--- Maximum sensible absolute value for heading shift.
--- Headings span levels 1-6, so a shift outside [-5, 5] always saturates.
local MAX_SHIFT_MAGNITUDE = 5

--- Load modules
local log = require(quarto.utils.resolve_path('_modules/logging.lua'):gsub('%.lua$', ''))
local validation = require(quarto.utils.resolve_path('_modules/validation.lua'):gsub('%.lua$', ''))
local content = require(quarto.utils.resolve_path('_modules/content-extraction.lua'):gsub('%.lua$', ''))
local header_utils = require(quarto.utils.resolve_path('_modules/header-utils.lua'):gsub('%.lua$', ''))

--- In-memory cache of fetched file contents, keyed by URI.
--- Avoids refetching the same file for repeated shortcodes in one render.
--- Lifetime is one Lua state, which Quarto re-creates per render, so this
--- never leaks across documents in batch renders.
--- @type table<string, string>
local fetch_cache = {}

--- Fetch file contents, using the in-process cache when possible.
--- @param uri string File URI to fetch
--- @return string|nil Contents, or nil on fetch failure
local function fetch_contents(uri)
  if fetch_cache[uri] ~= nil then
    return fetch_cache[uri]
  end
  local _mt, fetched = pandoc.mediabag.fetch(uri)
  if not fetched then
    return nil
  end
  fetch_cache[uri] = fetched
  return fetched
end

--- Strip YAML frontmatter from markdown source.
--- Handles both standard `---\n...\n---\n` blocks and the edge case where
--- the closing `---` has no trailing newline (the file ends at the fence).
--- @param contents string Raw file contents
--- @return string Contents without YAML frontmatter
local function strip_yaml_frontmatter(contents)
  if contents == nil or contents == '' then
    return contents or ''
  end
  if not contents:match('^%s*%-%-%-') then
    return contents
  end
  local _, yaml_end = contents:find('\n%-%-%-%s*\n', 1, false)
  if not yaml_end then
    -- Closing fence at end of string with no trailing newline.
    _, yaml_end = contents:find('\n%-%-%-%s*$', 1, false)
  end
  if yaml_end then
    return contents:sub(yaml_end + 1)
  end
  return contents
end

--- Escape every Quarto shortcode in the source so it renders verbatim.
--- Iterates from innermost to outermost using opaque placeholders so a
--- shortcode body containing another shortcode is handled correctly.
--- Each `{{< ... >}}` becomes `{{{< ... >}}}` (Quarto's literal form).
--- @param source string Source markdown
--- @return string Source with all shortcodes escaped
local function escape_shortcodes(source)
  if source == nil or source == '' then
    return source or ''
  end
  --- @type table<integer, string> Stored escaped tokens.
  local store = {}
  --- @type integer Placeholder index counter.
  local idx = 0
  --- @type string|nil Previous iteration value, for fixed-point detection.
  local prev
  --- @type integer Safety counter to avoid pathological inputs.
  local iter = 0
  -- The pattern excludes `{` and `}` in the body, so each pass only matches
  -- shortcodes that contain no nested shortcodes. Replacing matches with
  -- placeholders that contain no braces exposes the next-outer layer on the
  -- following pass, working outward to a fixed point.
  repeat
    iter = iter + 1
    if iter > 100 then
      break
    end
    prev = source
    source = source:gsub('{{<([^{}]-)[ \t]>}}', function(body)
      idx = idx + 1
      store[idx] = '{{{<' .. body .. ' >}}}'
      return '\x01' .. idx .. '\x02'
    end)
  until source == prev
  -- Placeholders use control characters that never appear in the escaped form,
  -- so a single pass restores every one.
  source = source:gsub('\x01(%d+)\x02', function(n)
    return store[tonumber(n)]
  end)
  return source
end

--- Parse the URI fragment into a line range, section/div ID, or nothing.
--- Accepts:
---   * `L10`        single line.
---   * `L10-20`     inclusive line range.
---   * `L10-L20`    inclusive line range (either form of the closing marker).
---   * `<id>`       header or div identifier.
--- @param fragment string|nil Fragment after `#`
--- @return string|nil identifier, integer|nil line_start, integer|nil line_end
local function parse_fragment(fragment)
  if fragment == nil or fragment == '' then
    return nil, nil, nil
  end
  --- @type integer|nil, integer|nil Parsed line bounds.
  local line_start, line_end
  line_start, line_end = fragment:match('^[Ll](%d+)%-[Ll]?(%d+)$')
  if line_start and line_end then
    return nil, tonumber(line_start), tonumber(line_end)
  end
  local single = fragment:match('^[Ll](%d+)$')
  if single then
    --- @type integer Single-line bound.
    local n = tonumber(single)
    return nil, n, n
  end
  return fragment, nil, nil
end

--- Slice the raw contents by 1-based inclusive line range.
--- @param contents string Raw file contents
--- @param line_start integer First line (1-based)
--- @param line_end integer Last line (1-based)
--- @return string|nil Joined slice, or nil if range is empty
local function slice_by_lines(contents, line_start, line_end)
  if line_start > line_end then
    return nil
  end
  --- @type table<integer, string> Collected lines from the slice.
  local lines = {}
  --- @type integer Current 1-based line counter.
  local i = 0
  for line in (contents .. '\n'):gmatch('([^\n]*)\n') do
    i = i + 1
    if i >= line_start and i <= line_end then
      lines[#lines + 1] = line
    end
    if i > line_end then
      break
    end
  end
  if #lines == 0 then
    return nil
  end
  return table.concat(lines, '\n')
end

--- Compute the longest leading whitespace prefix common to all non-blank lines.
--- @param text string Code-block content
--- @return integer Common indent width in characters
local function common_indent(text)
  --- @type integer|nil Minimum leading space found so far.
  local min_indent
  for line in (text .. '\n'):gmatch('([^\n]*)\n') do
    if line:match('%S') then
      --- @type string Leading whitespace of this line.
      local indent = line:match('^(%s*)') or ''
      --- @type integer Length of leading whitespace.
      local len = #indent
      if min_indent == nil or len < min_indent then
        min_indent = len
      end
    end
  end
  return min_indent or 0
end

--- Dedent code-block content by stripping the common leading indent.
--- @param text string Code-block content
--- @return string Dedented text
local function dedent_text(text)
  if text == nil or text == '' then
    return text or ''
  end
  --- @type integer Width to strip from each line.
  local width = common_indent(text)
  if width == 0 then
    return text
  end
  --- @type table<integer, string> Lines with indent removed.
  local lines = {}
  for line in (text .. '\n'):gmatch('([^\n]*)\n') do
    if #line >= width then
      lines[#lines + 1] = line:sub(width + 1)
    else
      lines[#lines + 1] = line
    end
  end
  -- When the input ends in a newline the sentinel produces an extra empty
  -- entry; drop it so the rejoined output preserves the original line count.
  if lines[#lines] == '' then
    table.remove(lines)
  end
  return table.concat(lines, '\n')
end

--- Walk blocks and dedent every CodeBlock's text (returns new block list).
--- Uses `pandoc.walk_block` on a wrapping Div so nested CodeBlocks (in
--- BlockQuotes, Divs, etc.) are also dedented.
--- @param blocks table<integer, table> Pandoc blocks to process
--- @return table<integer, table> Blocks with code dedented
local function dedent_code_blocks(blocks)
  if blocks == nil then
    return {}
  end
  --- @type table Walked wrapper Div with dedented CodeBlocks inside.
  local walked = pandoc.walk_block(pandoc.Div(blocks), {
    CodeBlock = function(cb)
      cb.text = dedent_text(cb.text)
      return cb
    end
  })
  return walked.content
end

--- Parse a kwarg into a boolean, accepting `true`/`false`/`1`/`0`/`yes`/`no`.
--- @param value any Raw kwarg value
--- @return boolean|nil Parsed boolean, or nil when the value is empty
local function parse_bool(value)
  if value == nil then
    return nil
  end
  --- @type string Stringified kwarg.
  local s = pandoc.utils.stringify(value)
  if s == '' then
    return nil
  end
  s = s:lower()
  if s == 'true' or s == '1' or s == 'yes' then
    return true
  end
  if s == 'false' or s == '0' or s == 'no' then
    return false
  end
  return nil
end

--- Parse blocks from raw markdown, dispatching on `.qmd` vs `.md/.markdown`.
--- For Markdown files, every shortcode in the source is escaped first so it
--- renders as literal text (Quarto would otherwise reinterpret it).
--- @param source string Raw markdown source
--- @param uri string Source URI, used to detect `.qmd` files
--- @return table Parsed Pandoc blocks
local function parse_blocks(source, uri)
  if uri:lower():match('%.qmd$') then
    return quarto.utils.string_to_blocks(source)
  end
  return pandoc.read(escape_shortcodes(source)).blocks
end

--- Includes external content or a section/div from a file into a Pandoc document.
--- Supports including entire markdown files, specific sections identified by header IDs,
--- divs identified by their IDs, or a line range (`#L<start>-<end>` or `#L<n>`).
--- For `.qmd` files, uses Quarto's `string_to_blocks` parser.
--- For other markdown files, uses Pandoc's reader with shortcode escaping.
---
--- @param args table Arguments array where first element is the file URI (with optional #id or #L<n>-<m>)
--- @param kwargs table Named keyword arguments (shift-heading-level-by, shift, dedent)
--- @param _meta table Document metadata (unused)
--- @param _raw_args table Raw arguments (unused)
--- @param _context table Context information (unused)
--- @return table Included content blocks or pandoc.Null() on error
--- @usage {{< external path/to/file.md#section-id >}}
--- @usage {{< external path/to/file.md#div-id >}}
--- @usage {{< external path/to/file.md#L10-20 >}}
--- @usage {{< external path/to/file.md dedent=true >}}
local function include_external(args, kwargs, _meta, _raw_args, _context)
  --- @type string File URI to include
  local uri = pandoc.utils.stringify(args[1])
  --- @type string|nil Raw fragment after `#`, if present
  local fragment = nil
  --- @type integer|nil Position of hash character in URI
  local hash_index = uri:find('#')
  if hash_index then
    fragment = uri:sub(hash_index + 1)
    uri = uri:sub(1, hash_index - 1)
  end

  --- @type string|nil Section or div identifier from fragment
  --- @type integer|nil First requested line (1-based, inclusive)
  --- @type integer|nil Last requested line (1-based, inclusive)
  local element_id, line_start, line_end = parse_fragment(fragment)

  --- @type integer|nil Heading level shift amount
  local shift = nil
  --- @type string Raw shift value from kwargs.
  --- Quarto passes an empty Inlines list for an attribute the author did not
  --- write, and an empty list is truthy in Lua, so `a or b` always stops at
  --- the first name and the `shift` alias is never read. Each candidate is
  --- stringified and tested for emptiness instead.
  local shift_value = ''
  for _, key in ipairs({ 'shift-heading-level-by', 'shift' }) do
    if shift_value == '' then
      shift_value = pandoc.utils.stringify(kwargs[key] or '')
    end
  end
  if shift_value ~= '' then
    shift = tonumber(shift_value)
    if shift == nil then
      log.log_warning(
        EXTENSION_NAME,
        'Invalid shift-heading-level-by value \'' .. shift_value .. '\'. ' ..
        'Expected an integer. Headings will not be shifted.'
      )
    else
      -- Normalise to integer so floats like 1.5 do not silently round.
      if shift ~= math.floor(shift) then
        log.log_warning(
          EXTENSION_NAME,
          'shift-heading-level-by value \'' .. shift_value .. '\' is not an integer. ' ..
          'Truncating towards zero.'
        )
        shift = (shift < 0) and math.ceil(shift) or math.floor(shift)
      end
      if math.abs(shift) > MAX_SHIFT_MAGNITUDE then
        log.log_warning(
          EXTENSION_NAME,
          'shift-heading-level-by value \'' .. shift_value .. '\' is outside the sensible ' ..
          'range [-' .. MAX_SHIFT_MAGNITUDE .. ', ' .. MAX_SHIFT_MAGNITUDE .. ']. ' ..
          'Out-of-range headings will be capped (at h6) or demoted to bold paragraphs (below h1).'
        )
      end
    end
  end

  --- @type boolean|nil Whether to dedent CodeBlock contents in included blocks.
  local dedent = parse_bool(kwargs['dedent'])

  -- Use validation module to check markdown extension
  if not validation.is_markdown(uri) then
    log.log_warning(
      EXTENSION_NAME,
      'Only markdown files (.md, .markdown, .qmd) are supported. ' ..
      'The file \'' .. uri .. '\' will not be included.'
    )
    return pandoc.Null()
  end

  --- @type string|nil Contents of the fetched file
  local contents = fetch_contents(uri)
  if not contents then
    log.log_error(
      EXTENSION_NAME,
      'Could not open file \'' .. uri .. '\'. ' ..
      'Please check that the file path is correct and the file is accessible.'
    )
    return pandoc.Null()
  end

  -- Line-range request: slice raw text first, then parse the slice.
  if line_start and line_end then
    --- @type string|nil Raw slice between line_start and line_end (inclusive).
    local slice = slice_by_lines(contents, line_start, line_end)
    if slice == nil then
      log.log_error(
        EXTENSION_NAME,
        'Line range \'L' .. line_start .. '-' .. line_end .. '\' is empty in \'' .. uri .. '\'. ' ..
        'Check that the file has at least ' .. line_end .. ' lines and that start <= end.'
      )
      return pandoc.Null()
    end
    --- @type table Pandoc blocks parsed from the slice.
    local slice_blocks = parse_blocks(slice, uri)
    if dedent then
      slice_blocks = dedent_code_blocks(slice_blocks)
    end
    if shift then
      slice_blocks = header_utils.shift_headers(slice_blocks, shift)
    end
    return pandoc.Blocks(slice_blocks)
  end

  --- @type string Source to parse into blocks
  local source = element_id and strip_yaml_frontmatter(contents) or contents
  --- @type table Pandoc blocks parsed from source
  local contents_blocks = parse_blocks(source, uri)

  if element_id then
    --- @type table|nil Blocks for the requested section.
    local section_blocks = content.extract_section(contents_blocks, element_id, true)
    if section_blocks then
      if dedent then
        section_blocks = dedent_code_blocks(section_blocks)
      end
      if shift then
        section_blocks = header_utils.shift_headers(section_blocks, shift)
      end
      return pandoc.Blocks(section_blocks)
    end

    --- @type table|nil Blocks for the requested div.
    local div_blocks = content.extract_div(contents_blocks, element_id, false)
    if div_blocks then
      if dedent then
        div_blocks = dedent_code_blocks(div_blocks)
      end
      if shift then
        div_blocks = header_utils.shift_headers(div_blocks, shift)
      end
      return pandoc.Blocks(div_blocks)
    end

    log.log_error(
      EXTENSION_NAME,
      'Section or div \'#' .. element_id .. '\' not found in \'' .. uri .. '\'. ' ..
      'Please check that the identifier matches a header or div in the file, ' ..
      'or use \'#L<start>-<end>\' for a line range.'
    )
    return pandoc.Null()
  end

  if dedent then
    contents_blocks = dedent_code_blocks(contents_blocks)
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
