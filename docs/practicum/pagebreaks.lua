-- Each lab opens on a new page. Background chapters flow normally, avoiding
-- near-empty pages caused by the report class's unconditional chapter breaks.
local bibliography = false

function Header(header)
  if not FORMAT:match('latex') then return end
  if header.level == 1 then
    bibliography = header.identifier == 'bibliography'
  end
  if header.level == 1 and (header.identifier:match('^lab%-') or
      header.identifier == 'measurements' or bibliography) then
    return {pandoc.RawBlock('latex', '\\clearpage'), header}
  end
  if bibliography and header.level == 2 then
    return {pandoc.RawBlock('latex', '\\Needspace{8\\baselineskip}'), header}
  end
  if header.level == 1 then
    return {pandoc.RawBlock('latex', '\\Needspace{10\\baselineskip}'), header}
  end
end
