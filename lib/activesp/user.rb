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
    
    def attributes_before_type_cast
      clean_attributes(data.attributes)
    end
    cache :attributes_before_type_cast
    
    def original_attributes
      type_cast_attributes(@site, nil, internal_attribute_types, attributes_before_type_cast)
    end
    cache :original_attributes
    
    def internal_attribute_types
      @@internal_attribute_types ||= {
        "Email" => GhostField.new("Email", "Text", false, true),
        "ID" => GhostField.new("ID", "Text", false, true),
        "IsDomainGroup" => GhostField.new("Email", "Bool", false, true),
        "IsSiteAdmin" => GhostField.new("IsSiteAdmin", "Bool", false, true),
        "LoginName" => GhostField.new("LoginName", "Text", false, true),
        "Name" => GhostField.new("Name", "Text", false, true),
        "Notes" => GhostField.new("Notes", "Text", false, true),
        "Sid" => GhostField.new("Sid", "Text", false, true)
      }
    end
    
  end
  
end
