module ActiveSP
  
  class PermissionSet
    
    include Util
    
    attr_reader :scope
    
    # @private
    def initialize(scope)
      @scope = scope
    end
    
    # See {Base#key}
    # @return [String]
    def key
      encode_key("P", [@scope.key])
    end
    
    # Returns the permissions in this permission set as an array of hashes with :accessor mapping to a user,
    # group or role and :mask mapping to the permission as an integer
    # @return [Array<Hash{:accessor, :permission => User, Group, Role, Integer}>]
    # @example
    #   set.permissions #=> [{:accessor=>#<ActiveSP::User login_name=SHAREPOINT\system>, :mask=>134287360}]
    def permissions
      @scope.send(:permissions)
    end
    
    # @private
    def to_s
      "#<ActiveSP::PermissionSet scope=#{@scope}>"
    end
    
    # @private
    alias inspect to_s
    
  end
  
end
