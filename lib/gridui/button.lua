local Button = {}
Button.__index = Button

function Button.new(opts)
  local obj = {}
  obj.x = opts.x or 1
  obj.y = opts.y or 1
  obj.off = opts.off or 0
  obj.on = opts.on or 15
  obj.state = 0
  obj.action = opts.action
  obj.hidden = opts.hidden or false
  obj.level = opts.level or 0
  return setmetatable(obj, Button)
end

function Button:key(x, y, s)
  if self.hidden or x ~= self.x or y ~= self.y then
    return false
  end
  self.state = s
  if self.action then
    self.action(self.state)
  end
  return true
end

function Button:redraw(g)
  if self.hidden then
    return
  end
  if self.level > 0 then
    g:led(self.x, self.y, self.level)
  elseif self.state > 0 then
    g:led(self.x, self.y, self.on)
  else
    g:led(self.x, self.y, self.off)
  end
end

return Button
