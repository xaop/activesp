module ActiveSP
  
  class Group < Base
    
    extend Caching
    extend PersistentCaching
    include Util
    include InSite
    
    # attr_reader :name
    
    persistent { |site, name, *a| [site.connection, [:group, name]] }
    def initialize(site, name)
      @site, @name = site, name
    end
    
    def key
      encode_key("G", [@name])
    end
    
    def users
      call("UserGroup", "get_user_collection_from_group", "groupName" => @name).xpath("//spdir:User", NS).map do |row|
        attributes = clean_attributes(row.attributes)
        User.new(@site, attributes["LoginName"])
      end
    end
    cache :users, :dup => true
    
    def to_s
      "#<ActiveSP::Group name=#{@name}>"
    end
    
    alias inspect to_s
    
    def is_role?
      false
    end
    
  private
    
    def data
      call("UserGroup", "get_group_info", "groupName" => @name).xpath("//spdir:Group", NS).first
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
        "OwnerID" => GhostField.new("OsnerID", "Integer", false, true),
        "OwnerIsUser" => GhostField.new("OwnerIsUser", "Bool", false, true)
      }
    end
    
  end
  
end
