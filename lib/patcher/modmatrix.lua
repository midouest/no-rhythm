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
  assert(sink:connect(source.type), "invalid normal connection")
  self.normal[sink.id] = source.id
end

function ModMatrix:connect(source_id, sink_id)
  local source = self.sources[source_id]
  local sink = self.sinks[sink_id]
  if not sink:connect(source.type) then
    return false
  end

  if self.matrix[sink.id][source.id] then
    return true
  end

  self.matrix[sink.id][source.id] = true
  local prev_connections = #self.connection_order
  table.insert(self.connection_order[sink.id], source.id)
  if prev_connections == 0 then
    if sink.connected then
      sink.connected()
    end
  end
  self:update_sink(sink.id)
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
    if sink.disconnected then
      sink.disconnected()
    end
    sink:receive({0})
  else
    self:update_sink(sink.id)
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
end

function ModMatrix:update_sink(sink_id)
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
    local value = source:read()
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
