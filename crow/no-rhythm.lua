function init_dyn_env(i)
  output[i].action = ar(0, dyn{decay=1}, dyn{level=8}, 'log')
end

function dyn_env(i, s, t)
  output[i].dyn.level = s
  output[i].dyn.decay = t
  output[i]()
end
