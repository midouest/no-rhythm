local Source = include("lib/patcher/source")
local Sink = include("lib/patcher/sink")

local ModMatrix = {}
ModMatrix.__index = ModMatrix

function ModMatrix.new()
  local obj = {}
  obj.sources = {}
  obj.sinks = {}
  obj.sink_order = {}
  obj.connection_order = {}
  obj.matrix = {}
  obj.normal = {}
  return setmetatable(obj, ModMatrix)
end

function ModMatrix:init()
  for _, sink in pairs(self.sinks) do
    sink:init()
  end
end

function ModMatrix:add_source(opts)
  local source = Source.new(opts)
  self.sources[source.id] = source
end

function ModMatrix:add_sink(opts)
  local sink = Sink.new(opts)
  self.sinks[sink.id] = sink
  table.insert(self.sink_order, sink.id)
  self.matrix[sink.id] = {}
  self.connection_order[sink.id] = {}
end

function ModMatrix:normalize(source_id, sink_id)
  local source = self.sources[source_id]
  local sink = self.sinks[sink_id]
  local mode = self:connection_type(sink.id, source.id)
  assert(mode ~= nil, "invalid normal connection")
  source:set_mode(mode)
  sink:set_mode(mode)
  self.normal[sink.id] = source.id
end

function ModMatrix:connection_type(source_id, sink_id)
  local source = self.sources[source_id]
  local sink = self.sinks[sink_id]
  
  local source_types = source.type
  if type(source_types) == "string" then
    source_types = {source_types}
  end

  local sink_types = {"gate","cv", "env"}
  for _, sink_type in ipairs({"gate", "cv", "env"}) do
    if type(sink[sink_type]) == "function" then
      for _, source_type in ipairs(source_types) do
        if source_type == sink_type then
          return source_type
        end
      end
    end
  end
end

function ModMatrix:connect(source_id, sink_id)
  local mode = self:connection_type(source_id, sink_id)
  if mode == nil then
    return false
  end

  local source = self.sources[source_id]
  local sink = self.sinks[sink_id]
  if self.matrix[sink.id][source.id] then
    return true
  end

  if mode ~= source.mode then
    for other_sink_id, other_conns in pairs(self.matrix) do
      if other_conns[source.id] then
        self:disconnect(source.id, other_sink_id)
      end
    end
  end
  if mode ~= sink.mode then
    for source_id, _ in pairs(self.matrix[sink.id]) do
      self.matrix[sink.id] = {}
      self.connection_order[sink.id] = {}
    end
  end

  source:set_mode(mode)
  sink:set_mode(mode)

  self.matrix[sink.id][source.id] = true
  table.insert(self.connection_order[sink.id], source.id)
  self:update_sink(sink.id, true)
  return true
end

function ModMatrix:disconnect(source_id, sink_id)
  local source = self.sources[source_id]
  local sink = self.sinks[sink_id]
  self.matrix[sink.id][source.id] = nil
  local prev_connections = #self.connection_order[sink.id]
  for i, sid in ipairs(self.connection_order[sink.id]) do
    if sid == source.id then
      table.remove(self.connection_order[sink.id], i)
      break
    end
  end

  if prev_connections > 0 and #self.connection_order[sink.id] == 0 then
    sink:receive({0})
  else
    self:update_sink(sink.id, true)
  end
end

function ModMatrix:toggle(source_id, sink_id)
  if self.matrix[sink_id][source_id] then
    self:disconnect(source_id, sink_id)
  else
    self:connect(source_id, sink_id)
  end
end

function ModMatrix:send(source_id, value)
  local source = self.sources[source_id]
  source:send(value)
end

function ModMatrix:update()
  for _, sink_id in ipairs(self.sink_order) do
    self:update_sink(sink_id)
  end
  for _, source in pairs(self.sources) do
    source:mark_clean()
  end
end

function ModMatrix:update_sink(sink_id, force)
  local sink = self.sinks[sink_id]
  local source_ids = self.matrix[sink.id]
  local values = {}
  local normal_source_id = self.normal[sink.id]
  
  local broken = false
  for _, _ in pairs(source_ids) do
    broken = true
    break
  end
  if not broken and normal_source_id then
    source_ids = {[normal_source_id]=true}
  end
  
  for source_id, _ in pairs(source_ids) do
    local source = self.sources[source_id]
    local value = nil
    if force then
      value = source.state
    else
      value = source:read()
    end
    if value ~= nil then
      if sink.external and source.transform then
        value = source.transform(value)
      end
      table.insert(values, value)
    end
  end

  if #values > 0 then
    sink:receive(values)
  end
end

return ModMatrix
