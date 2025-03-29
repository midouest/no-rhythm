local Source = {}
Source.__index = Source

function Source.new(opts)
  local obj = {}
  obj.id = opts.id
  obj.type = opts.type
  obj.init = opts.init
  obj.action = opts.action
  obj.transform = opts.transform
  obj.state = nil
  obj.dirty = false
  obj.mode = nil
  return setmetatable(obj, Source)
end

function Source:set_mode(sink_type)
  local prev_mode = self.mode
  self.mode = sink_type
  if self.mode ~= prev_mode then
    if self.init then
      self.init(self.mode)
    end
  end
end

function Source:send(value)
  local prev_state = self.state
  self.state = value
  self.dirty = self.dirty or self.state ~= prev_state
  if self.dirty then
    if self.action then
      self.action(self.state)
    end
  end
end

function Source:read()
  if not self.dirty then
    return nil
  end
  return self.state
end

function Source:mark_clean()
  self.dirty = false
  if self.mode == "env" then
    self.state = nil
  end
end

return Source
