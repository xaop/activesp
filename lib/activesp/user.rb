module ActiveSP
  
  class User < Base
    
    extend Caching
    extend PersistentCaching
    include Util
    include InSite
    
    # @private
    attr_reader :login_name
    
    persistent { |site, login_name, *a| [site.connection, [:user, login_name]] }
    # @private
    def initialize(site, login_name, attributes_before_type_cast = nil)
      @site, @login_name = site, login_name
      @attributes_before_type_cast = attributes_before_type_cast if attributes_before_type_cast
    end
    
    # See {Base#key}
    # @return [String]
    def key
      encode_key("U", [@login_name])
    end
    
    # See {Base#save}
    # @return [void]
    def save
      p untype_cast_attributes(@site, nil, internal_attribute_types, changed_attributes)
    end
    
    # @private
    def to_s
      "#<ActiveSP::User login_name=#{login_name}>"
    end
    
    # @private
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
    
    def current_attributes_before_type_cast
      untype_cast_attributes(@site, nil, internal_attribute_types, current_attributes)
    end
    
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
