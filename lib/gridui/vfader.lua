local VFader = {}
VFader.__index = VFader

function VFader.new(opts)
  local obj = {}
  obj.x = opts.x or 1
  obj.value = opts.initial or 0
  obj.action = opts.action
  obj.hidden = opts.hidden or false
  return setmetatable(obj, VFader)
end

function VFader:key(x, y, s)
  if self.hidden or x ~= self.x then
    return false
  end
  if s == 1 then
    local i = 9 - y
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

function VFader:redraw(g)
  if self.hidden then
    return
  end
  local fill = self.value // 16
  local rem = self.value % 16
  for i=1,fill do
    g:led(self.x, 9-i, 15)
  end
  g:led(self.x, 8-fill, rem)
end

return VFader
