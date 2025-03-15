local HFader = {}
HFader.__index = HFader

function HFader.new(opts)
  local obj = {}
  obj.x = opts.x or 1
  obj.y = opts.y or 1
  obj.value = opts.initial or 0
  obj.action = opts.action
  obj.hidden = opts.hidden or false
  return setmetatable(obj, HFader)
end

function HFader:key(x, y, s)
  if self.hidden or y ~= self.y or x < self.x or x >= self.x + 8 then
    return false
  end
  if s == 1 then
    local i = x - self.x + 1
    local prev_value = self.value
    if i == 1 then
      if prev_value == 0 then
        self.value = 15
      else
        self.value = 0
      end
    else
      self.value = i * 16 - 1
    end
    if self.value ~= prev_value and self.action then
      self.action(self.value)
    end
  end
  return true
end

function HFader:redraw(g)
  if self.hidden then
    return
  end
  local fill = self.value // 16
  local rem = self.value % 16
  for i=1,fill do
    g:led(self.x+i-1, self.y, 15)
  end
  g:led(self.x+fill, self.y, rem)
end

return HFader
