--- Header utilities for Quarto extensions
--- @module header_utils
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil

local header_utils = {}

--- Shift heading levels in blocks by a specified amount.
--- Adjusts all Header blocks by adding the shift value to their level.
--- Handles edge cases: levels < 1 become paragraphs, levels > 6 are capped at 6.
---
--- @param blocks table<integer, table> Array of Pandoc blocks to process
--- @param shift integer Amount to shift heading levels (positive demotes, negative promotes)
--- @return table<integer, table> Modified blocks with shifted header levels
--- @usage local shifted = header_utils.shift_headers(blocks, 1)  -- h1 → h2, h2 → h3
--- @usage local shifted = header_utils.shift_headers(blocks, -1) -- h2 → h1, h3 → h2
function header_utils.shift_headers(blocks, shift)
  if blocks == nil or shift == nil or shift == 0 then
    return blocks or {}
  end

  --- @type table<integer, table> Result blocks
  local shifted = {}

  for _, block in ipairs(blocks) do
    if block.t == 'Header' then
      --- @type integer New heading level after shift
      local new_level = block.level + shift

      if new_level < 1 then
        -- Convert to paragraph with strong text (matching Quarto document-level behaviour)
        --- @type table Paragraph containing the header content as strong text
        local para_content = { pandoc.Strong(block.content) }
        table.insert(shifted, pandoc.Para(para_content))
      else
        -- Cap at level 6 if exceeds maximum
        if new_level > 6 then
          new_level = 6
        end
        -- Create new header with shifted level, preserving attributes
        table.insert(shifted, pandoc.Header(
          new_level,
          block.content,
          pandoc.Attr(block.identifier, block.classes, block.attributes)
        ))
      end
    else
      -- Keep non-header blocks unchanged
      table.insert(shifted, block)
    end
  end

  return shifted
end

return header_utils
