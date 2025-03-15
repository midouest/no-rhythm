local Fader = {}
Fader.__index = Fader

function Fader.new(opts)
  local obj = {}
  local x = opts.x or 1
  local y = opts.y or 1
  
  return setmetatable(obj, Fader)
end

function Fader:key(x, y, s)
  if y ~= self.y 
end

function Fader:redraw(g)
  
end

return Fader
