module ActiveSP
  
  class Group < Base
    
    extend Caching
    extend PersistentCaching
    include Util
    include InSite
    
    persistent { |site, name, *a| [site.connection, [:group, name]] }
    # @private
    def initialize(site, name)
      @site, @name = site, name
    end
    
    # See {Base#key}
    # @return [String]
    def key
      encode_key("G", [@name])
    end
    
    # Returns the list of users in this group
    # @return [User]
    def users
      call("UserGroup", "get_user_collection_from_group", "groupName" => @name).xpath("//spdir:User", NS).map do |row|
        attributes = clean_attributes(row.attributes)
        User.new(@site, attributes["LoginName"])
      end
    end
    cache :users, :dup => :always
    
    # Returns false. The same method is present on {Role} where it returns true. Roles and groups can generally be
    # duck-typed, and this method is there for the rare case where you do need to make the distinction
    # @return [Boolean]
    def is_role?
      false
    end
    
    # See {Base#save}
    # @return [void]
    def save
      p untype_cast_attributes(@site, nil, internal_attribute_types, changed_attributes)
    end
    
    # @private
    def to_s
      "#<ActiveSP::Group name=#{@name}>"
    end
    
    # @private
    alias inspect to_s
    
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
    
    def current_attributes_before_type_cast
      untype_cast_attributes(@site, nil, internal_attribute_types, current_attributes)
    end
    
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
