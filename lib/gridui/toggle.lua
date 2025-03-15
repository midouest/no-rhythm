local Toggle = {}
Toggle.__index = Toggle

function Toggle.new(opts)
  local obj = {}
  obj.x = opts.x or 1
  obj.y = opts.y or 1
  obj.off = opts.off or 0
  obj.on = opts.on or 15
  obj.state = opts.initial or 0
  obj.action = opts.action
  obj.hidden = opts.hidden or false
  return setmetatable(obj, Toggle)
end

function Toggle:key(x, y, s)
  if self.hidden or x ~= self.x or y ~= self.y then
    return false
  end
  if s == 1 then
    self.state = 1 - self.state
    if self.action then
      self.action(self.state)
    end
  end
  return true
end

function Toggle:redraw(g)
  if self.hidden then
    return
  end
  if self.state > 0 then
    g:led(self.x, self.y, self.on)
  else
    g:led(self.x, self.y, self.off)
  end
end

return Toggle
