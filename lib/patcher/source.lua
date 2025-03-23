local Source = {}
Source.__index = Source

function Source.new(opts)
  local obj = {}
  obj.id = opts.id
  obj.type = opts.type
  obj.state = nil
  obj.dirty = false
  return setmetatable(obj, Source)
end

function Source:send(value)
  local prev_state = self.state
  self.state = value
  self.dirty = self.dirty or self.state ~= prev_state
end

function Source:read()
  if not self.dirty then
    return nil
  end

  local value = self.state
  self.dirty = false
  if self.type == "env" then
    self.state = nil
  end
  return value
end

return Source
