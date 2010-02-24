module ActiveSP
  
  class Field
    
    attr_reader :name, :type, :data
    
    def initialize(site, name, type, data)
      @site, @name, @type, @data = site, name, type, data
    end
    
    def list_for_lookup
      if %w[Lookup LookupMulti].include?(@type)
        list = @data["List"]
        if list[0] == ?{ && list[-1] == ?} # We have a GUID of a list
          ActiveSP::List.new(@site, list)
        end
      end
    end
    
    def to_s
      "#<ActiveSP::Field name=#{@name}>"
    end
    
    alias inspect to_s
    
  end
  
end
