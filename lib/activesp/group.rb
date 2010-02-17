module ActiveSP
  
  class Group < Base
    
    include Caching
    include Util
    include InSite
    
    attr_reader :name
    
    def initialize(site, name)
      @site, @name = site, name
    end
    
    def attributes
      attributes_before_type_cast
    end
    cache :attributes
    
    def attributes_before_type_cast
      data.attributes.inject({}) { |h, (k, v)| h[k] = v.to_s ; h }
    end
    cache :attributes_before_type_cast
    
    def key
      encode_key("G", [@name])
    end
    
    def to_s
      "#<ActiveSP::Group name=#{@name}>"
    end
    
    alias inspect to_s
    
  private
    
    def data
      call("UserGroup", "get_group_info", "groupName" => @name).xpath("//spdir:Group", NS).first
    end
    cache :data
    
  end
  
end
