local Sink = {}
Sink.__index = Sink

function Sink.new(opts)
  local obj = {}
  obj.id = opts.id
  obj.type = opts.type
  obj.external = opts.external or false
  obj._init = opts.init
  obj.connected = opts.connected
  obj.disconnected = opts.disconnected
  obj.gate = opts.gate
  obj.cv = opts.cv
  obj.env = opts.env
  for _, key in ipairs({"gate", "cv", "env"}) do
    if obj[key] then
      obj.mode = key
      break
    end
  end
  obj.state = nil
  return setmetatable(obj, Sink)
end

function Sink:init()
  if self._init then
    self._init(self.mode)
  end
end

function Sink:can_connect(source_type)
  return type(self[source_type]) == "function"
end

function Sink:connect(source_type)
  if not self:can_connect(source_type) then
    return false
  end
  
  if source_type ~= self.mode then
    self.mode = source_type
    self:init()
  end
  
  return true
end

function Sink:receive(source_values)
  if self.mode == 'gate' then
    local state = 0
    for _, value in ipairs(source_values) do
      if value > state then
        state = value
        break
      end
    end
    if state ~= self.state then
      self.state = state
      self.gate(self.state)
    end
  elseif self.mode == 'cv' then
    local state = 0
    for _, value in ipairs(source_values) do
      state = state + value
    end
    if state ~= self.state then
      self.state = state
      self.cv(self.state)
    end
  elseif self.mode == 'env' then
    local event = nil
    for _, e in ipairs(source_values) do
      if e ~= nil then
        event = e
        break
      end
    end
    if event ~= nil then
      self.env(event)
    end
  end
end

return Sink
