module ActiveSP
  
  class Role < Base
    
    extend Caching
    extend PersistentCaching
    include Util
    include InSite
    
    attr_reader :name
    
    persistent { |site, name, *a| [site.connection, [:role, name]] }
    def initialize(site, name)
      @site, @name = site, name
    end
    
    def key
      encode_key("R", [@name])
    end
    
    def users
      call("UserGroup", "get_user_collection_from_role", "roleName" => @name).xpath("//spdir:User", NS).map do |row|
        attributes = clean_attributes(row.attributes)
        User.new(@site, attributes["LoginName"])
      end
    end
    cache :users, :dup => true
    
    def groups
      call("UserGroup", "get_group_collection_from_role", "roleName" => @name).xpath("//spdir:Group", NS).map do |row|
        attributes = clean_attributes(row.attributes)
        Group.new(@site, attributes["Name"])
      end
    end
    cache :groups, :dup => true
    
    def to_s
      "#<ActiveSP::Role name=#{@name}>"
    end
    
    alias inspect to_s
    
    def is_role?
      true
    end
    
  private
    
    def data
      call("UserGroup", "get_role_info", "roleName" => @name).xpath("//spdir:Role", NS).first
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
        "Description" => GhostField.new("Description", "Text", false, true),
        "ID" => GhostField.new("ID", "Text", false, true),
        "Name" => GhostField.new("Name", "Text", false, true),
        "Type" => GhostField.new("Type", "Integer", false, true)
      }
    end
    
  end
  
end
