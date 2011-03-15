class MockCache
  def initialize
    @cache = {}
  end
  
  def read(key)
    @cache[key].to_s
  end
  
  def write(key, val)
    @cache[key] = val.to_s
  end
  
  def increment(key)
    @cache[key] = @cache[key].to_i + 1
  end
  
  def exist?(key)
    !!@cache[key]
  end
  
  def all(action, *args)
    self.send(action, *args)
  end
  
  def clear
    @cache = {}
  end
end  
