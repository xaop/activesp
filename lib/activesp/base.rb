module ActiveSP
  
  class Base
    
    extend Caching
    
    # Returns a key that can be used to retrieve this object later on using {Connection#find_by_key}
    # @return [String]
    def key
      raise "This is here for documentation purposes only"
    end
    
    # Returns the attributes of this object as a Hash
    # @return [Hash{String => Integer, Float, String, Time, Boolean, Base}]
    def attributes
      current_attributes
    end
    cache :attributes, :dup => :always
    
    # Returns the types of the attributes of this object as a Hash
    # @return [Hash{String => Field}]
    def attribute_types
      internal_attribute_types
    end
    cache :attribute_types, :dup => :always
    
    # Returns whether or not this object has an attribute with the given name
    # @param [String] name The name of the attribute
    # @return [Boolean]
    def has_attribute?(name)
      current_attributes.has_key?(name)
    end
    
    # Returns whether or not this object has an attribute with the given name that can be assigned to
    # @param [String] name The name of the attribute
    # @return [Boolean]
    def has_writable_attribute?(name)
      has_attribute?(name) and attr = internal_attribute_types[name] and !attr.ReadOnly
    end
    
    # Returns the value of the attribute of the given name, or nil if this object does not have an attribute by the given name
    # @param [String] name The name of the attribute
    # @return [Integer, Float, String, Time, Boolean, Base]
    def attribute(name)
      current_attributes[name]
    end
    
    # Returns the type of the attribute by the given name, or nil if this object does not have an attribute by the given name
    # @param [String] name The name of the attribute
    # @return [Field]
    def attribute_type(name)
      internal_attribute_types[name]
    end
    
    # Sets the attribute with the given name to the given value
    # @param [String] name The name of the attribute
    # @param [Integer, Float, String, Time, Boolean, Base] value The value to assign
    # @return [Integer, Float, String, Time, Boolean, Base] The assigned value
    # @raise [ArgumentError] Raised when this object does not have an attribute by the given name of if the attribute by the given name is read-only
    def set_attribute(name, value)
      has_attribute?(name) and field = attribute_type(name) and internal_attribute_types[name] or raise ArgumentError, "#{self} has no field by the name #{name}"
      !field.ReadOnly or raise ArgumentError, "field #{name} of #{self} is read-only"
      current_attributes[name] = type_check_attribute(field, value)
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
    
    # Reloads the object from the server
    # @return [void]
    def reload
    end
    
    # Saves the object to the server. Raises an exception when the save fails
    # @return [void]
    def save
    end
    
  private
    
    def current_attributes
      original_attributes
    end
    cache :current_attributes, :dup => :once
    
    def changed_attributes
      before = original_attributes
      after = current_attributes
      changes = {}
      after.each do |name, value|
        if before[name] != value
          changes[name] = value
        end
      end
      changes
    end
    
  end
  
end
