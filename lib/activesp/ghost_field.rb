module ActiveSP
  
  # This class represents the field definitions for objects in SharePoint for which the
  # fields cannot be changed and are thus not represented by an object in SharePoint.
  # These include fields of sites, lists, users, grouos, roles, content types and fields.
  # The interface of this class is not as complete as the interface if a Field, mainly
  # because it does not make much sense to do so
  class GhostField
    
    include Util
    
    # @private
    attr_reader :Name, :internal_type, :Mult, :ReadOnly
    
    # @private
    def initialize(name, type, mult, read_only)
      @Name, @internal_type, @Mult, @ReadOnly = name, type, mult, read_only
    end
    
    # @private
    def Type
      translate_internal_type(self)
    end
    
    # Returns the attributes of this object as a Hash
    # @return [Hash{String => Integer, Float, String, Time, Boolean, Base}]
    def attributes
      original_attributes.dup
    end
    
    # Returns the value of the attribute of the given name, or nil if this object does not have an attribute by the given name
    # @param [String] name The name of the attribute
    # @return [Integer, Float, String, Time, Boolean, Base]
    def attribute(name)
      current_attributes[name]
    end
    
    # Returns whether or not this object has an attribute with the given name
    # @param [String] name The name of the attribute
    # @return [Boolean]
    def has_attribute?(name)
      current_attributes.has_key?(name)
    end
    
    def method_missing(m, *a, &b)
      ms = m.to_s
      if a.length == 0 && has_attribute?(ms)
        attribute(ms)
      else
        super
      end
    end
    
  private
    
    def original_attributes
      @original_attributes ||= {
        "ColName" => @Name,
        "DisplayName" => @Name,
        "Mult" => @Mult,
        "Name" => @Name,
        "ReadOnly" => @ReadOnly,
        "StaticName" => @Name,
        "Type" => self.Type
      }
    end
    
  end
  
end
