local Group = {}
Group.__index = Group

function Group.new(opts)
  opts = opts or {}
  local obj = {}
  obj.hidden = opts.hidden or false
  obj.children = {}
  return setmetatable(obj, Group)
end

function Group:add(child)
  table.insert(self.children, child)
end

function Group:key(x, y, s)
  if self.hidden then
    return false
  end
  for _, child in ipairs(self.children) do
    if child:key(x, y, s) then
      return true
    end
  end
  return false
end

function Group:redraw(g)
  if self.hidden then
    return
  end
  for _, child in ipairs(self.children) do
    child:redraw(g)
  end
end

return Group
