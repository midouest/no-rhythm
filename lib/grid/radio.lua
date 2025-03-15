local Radio = {}
Radio.__index = Radio

function Radio.new(opts)
  local obj = {}
  obj.x = opts.x or 1
  obj.y = opts.y or 1
  obj.size = opts.size or 2
  obj.off = opts.off or 0
  obj.on = opts.on or 15
  obj.state = opts.initial or 1
  obj.action = opts.action
  obj.hidden = opts.hidden or false
  return setmetatable(obj, Radio)
end

function Radio:key(x, y, s)
  if self.hidden or x ~= self.x or y < self.y or y >= self.y + self.size then
    return false
  end
  if s == 1 then
    local prev = self.state
    self.state = y - self.y + 1
    if self.state ~= prev and self.action then
      self.action(self.state)
    end
  end
  return true
end

function Radio:redraw(g)
  if self.hidden then
    return
  end
  for i=1,self.size do
    if self.state == i then
      g:led(self.x, self.y + i - 1, self.on)
    else
      g:led(self.x, self.y + i - 1, self.off)
    end
  end
end

return Radio
