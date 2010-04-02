module ActiveSP
  
  class Base
    
    extend Caching
    
    def attributes
      current_attributes
    end
    cache :attributes, :dup => true
    
    def attribute_types
      internal_attribute_types
    end
    cache :attribute_types, :dup => true
    
    def has_attribute?(name)
      attributes.has_key?(name)
    end
    
    def has_writable_attribute?(name)
      has_attribute?(name) && !attribute_types[name].ReadOnly
    end
    
    def attribute(name)
      attributes[name]
    end
    
    def set_attribute(name, value)
      current_attributes[name] = value
    end
    
    def method_missing(m, *a, &b)
      ms = m.to_s
      if a.length == 0 && has_attribute?(ms)
        attribute(ms)
      elsif a.length == 1 && ms[-1] == ?= && has_writable_attribute?(ms[0..-2])
        set_attribute(ms[0..-2], *a)
      else
        super
      end
    end
    
  private
    
    def current_attributes
      original_attributes
    end
    cache :current_attributes
    
  end
  
end
