--[[
# MIT License
#
# Copyright (c) 2026 Mickaël Canouil
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

--- Header utilities for Quarto extensions
--- @module header_utils
--- @author Mickaël Canouil
--- @version 1.0.0

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
