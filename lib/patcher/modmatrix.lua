local Source = include("lib/patcher/source")
local Sink = include("lib/patcher/sink")

local ModMatrix = {}
ModMatrix.__index = ModMatrix

function ModMatrix.new()
  local obj = {}
  obj.sources = {}
  obj.sinks = {}
  obj.sink_order = {}
  obj.matrix = {}
  return setmetatable(obj, ModMatrix)
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
end

function ModMatrix:connect(source_id, sink_id)
  local source = self.sources[source_id]
  local sink = self.sinks[sink_id]
  if not sink:connect(source.type) then
    return false
  end
  self.matrix[sink.id][source.id] = true
  return true
end

function ModMatrix:disconnect(source_id, sink_id)
  local source = self.sources[source_id]
  local sink = self.sinks[sink_id]
  self.matrix[sink.id][source.id] = nil
end

function ModMatrix:send(source_id, value)
  local source = self.sources[source_id]
  source:send(value)
end

function ModMatrix:update()
  for _, sink_id in ipairs(self.sink_order) do
    local sink = self.sinks[sink_id]
    local source_ids = self.matrix[sink.id]
    local values = {}
    for source_id, _ in pairs(source_ids) do
      local source = self.sources[source_id]
      local value = source:read()
      if value ~= nil then
        table.insert(values, value)
      end
    end
    if #values > 0 then
      sink:receive(values)
    end
  end
end

return ModMatrix
