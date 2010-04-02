module ActiveSP
  
  class PermissionSet
    
    include Util
    
    attr_reader :scope
    
    def initialize(scope)
      @scope = scope
    end
    
    def permissions
      @scope.send(:permissions)
    end
    
    def key
      encode_key("P", [@scope.key])
    end
    
    def to_s
      "#<ActiveSP::PermissionSet scope=#{@scope}>"
    end
    
    alias inspect to_s
    
  end
  
end
