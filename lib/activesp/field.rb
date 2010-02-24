module ActiveSP
  
  class Field < Base
    
    include InSite
    extend Caching
    include Util
    
    attr_reader :scope, :id, :name, :type, :attributes_before_type_cast
    
    # There is no call to get to the field info directly, so these should always
    # be accessed through the site or list they belong to. Hence, we do not use
    # caching here as it is useless.
    def initialize(scope, id, name, type, attributes_before_type_cast)
      @scope, @id, @name, @type, @attributes_before_type_cast = scope, id, name, type, attributes_before_type_cast
      @site = Site === @scope ? @scope : @scope.site
    end
    
    def key
      encode_key("A", [@scope.key, @id])
    end
    
    def attributes
      @attributes ||= attributes_before_type_cast
    end
    
    def list_for_lookup
      if %w[Lookup LookupMulti].include?(@type)
        list = attributes["List"]
        if list[0] == ?{ && list[-1] == ?} # We have a GUID of a list
          ActiveSP::List.new(@site, list)
        end
      end
    end
    
    def to_s
      "#<ActiveSP::Field name=#{name}>"
    end
    
    alias inspect to_s
    
  end
  
end
