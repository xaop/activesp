module ActiveSP
  
  class GhostField
    
    include Util
    
    attr_reader :Name, :internal_type, :Mult, :ReadOnly
    
    def initialize(name, type, mult, read_only)
      @Name, @internal_type, @Mult, @ReadOnly = name, type, mult, read_only
    end
    
    def Type
      translate_internal_type(self)
    end
    
    def attributes
      @attributes ||= {
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
