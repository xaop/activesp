# Basically a placeholder
module ActiveSP
  
  class Base
    
    def has_attribute?(name)
      attributes.has_key?(ms)
    end
    
    def attribute(name)
      attributes[name]
    end
    
    def set_attribute(name, value)
      raise NotImplementedError, "assignment is not yet implemented"
    end
    
    def method_missing(m, *a, &b)
      ms = m.to_s
      if a.length == 0 && attributes.has_key?(ms)
        attribute(ms)
      elsif a.length == 1 && attributes.has_key?(ms[1..-1])
        set_attribute(ms, *a)
      else
        super
      end
    end
    
  end
  
end
