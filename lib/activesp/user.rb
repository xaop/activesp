module ActiveSP
  
  class User < Base
    
    extend Caching
    extend PersistentCaching
    include Util
    include InSite
    
    attr_reader :login_name
    
    persistent { |site, login_name, *a| [site.connection, [:user, login_name]] }
    def initialize(site, login_name)
      @site, @login_name = site, login_name
    end
    
    def attributes
      attributes_before_type_cast
    end
    cache :attributes, :dup => true
    
    def attributes_before_type_cast
      data.attributes.inject({}) { |h, (k, v)| h[k] = v.to_s ; h }
    end
    cache :attributes_before_type_cast, :dup => true
    
    def key
      encode_key("U", [@login_name])
    end
    
    def to_s
      "#<ActiveSP::User login_name=#{login_name}>"
    end
    
    alias inspect to_s
    
  private
    
    def data
      call("UserGroup", "get_user_info", "userLoginName" => @login_name).xpath("//spdir:User", NS).first
    end
    cache :data
    
  end
  
end
