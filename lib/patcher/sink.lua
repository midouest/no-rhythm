local Sink = {}
Sink.__index = Sink

function Sink.new(opts)
  local obj = {}
  obj.id = opts.id
  obj.type = opts.type
  obj.external = opts.external or false
  obj.init = opts.init
  obj.gate = opts.gate
  obj.cv = opts.cv
  obj.env = opts.env
  obj.mode = nil
  obj.state = nil
  return setmetatable(obj, Sink)
end

function Sink:set_mode(source_type)
  local prev_mode = self.mode
  self.mode = source_type
  if self.mode ~= prev_mode then
    if self.init then
      self.init(self.mode)
    end
  end
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
    if type(event) == "table" then
      self.env(event)
    end
  end
end

return Sink
