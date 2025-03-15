local Keyboard = {}
Keyboard.__index = Keyboard

local PATTERN = {
  {-1, 12},
  {10, 11},
  {8, 9},
  {6, 7},
  {-1, 5},
  {3, 4},
  {1, 2},
  {-1, 0},
}

function Keyboard.new(opts)
  local obj = {}
  obj.x = opts.x or 1
  obj.value = opts.value or 60
  obj.octave = opts.octave or obj.value // 12
  obj.action = opts.action
  obj.hidden = opts.hidden or false
  return setmetatable(obj, Keyboard)
end

function Keyboard:key(x, y, s)
  if self.hidden or x < self.x or x >= self.x + 2 then
    return false
  end
  if s == 1 then
    local prev_value = self.value
    if x == self.x then
      if y == 1 then
        self.octave = math.min(self.octave + 1, 10)
      elseif y == 8 then
        self.octave = math.max(self.octave - 1, 0)
      elseif y ~= 5 then
        self.value = self.octave * 12 + PATTERN[y][1]
      end
    else
      self.value = self.octave * 12 + PATTERN[y][2]
    end
    if self.value ~= prev_value and self.action then
      self.action(self.value)
    end
  end
  return true
end

function Keyboard:redraw(g)
  if self.hidden then
    return
  end
  for x = 1, 2 do
    for y = 1, 8 do
      if PATTERN[y][x] >= 0 then
        g:led(x + self.x - 1, y, 3)
      end
    end
  end
end

return Keyboard
