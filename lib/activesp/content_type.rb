module ActiveSP
  
  class ContentType < Base
    
    include InSite
    extend Caching
    extend PersistentCaching
    include Util
    
    attr_reader :id
    
    persistent { |site, list, id, *a| [site.connection, [:content_type, id]] }
    def initialize(site, list, id, name = nil, description = nil, version = nil, group = nil)
      @site, @list, @id = site, list, id
      @Name = name if name
      @Description = description if description
      @Version = version if version
      @Group = group if group
    end
    
    def scope
      @list || @site
    end
    
    def supertype
      superkey = split_id[0..-2].join("")
      (@list ? @list.content_type(superkey) : nil) || @site.content_type(superkey)
    end
    cache :supertype
    
    def key
      encode_key("T", [scope.key, @id])
    end
    
    def Name
      data["Name"].to_s
    end
    cache :Name
    
    def Description
      data["Description"].to_s
    end
    cache :Description
    
    def Version
      data["Version"].to_s
    end
    cache :Version
    
    def Group
      data["Group"].to_s
    end
    cache :Group
    
    def fields
      data.xpath("//sp:Field", NS).map { |field| scope.field(field["ID"]) }.compact
    end
    cache :fields, :dup => true
    
    def to_s
      "#<ActiveSP::ContentType Name=#{self.Name}>"
    end
    
    alias inspect to_s
    
  private
    
    def data
      if @list
        call("Lists", "get_list_content_type", "listName" => @list.id, "contentTypeId" => @id).xpath("//sp:ContentType", NS).first
      else
        call("Webs", "get_content_type", "contentTypeId" => @id).xpath("//sp:ContentType", NS).first
      end
    end
    cache :data
    
    def original_attributes
      type_cast_attributes(@site, nil, internal_attribute_types, clean_item_attributes(data.attributes))
    end
    cache :original_attributes
    
    def internal_attribute_types
      @@internal_attribute_types ||= {
        "Description" => GhostField.new("ColName", "Text", false, true),
        "FeatureId" => GhostField.new("ColName", "Text", false, true),
        "Group" => GhostField.new("ColName", "Text", false, true),
        "Hidden" => GhostField.new("Hidden", "Bool", false, true),
        "ID" => GhostField.new("ColName", "Text", false, true),
        "Name" => GhostField.new("ColName", "Text", false, true),
        "ReadOnly" => GhostField.new("ReadOnly", "Bool", false, true),
        "Sealed" => GhostField.new("Sealed", "Bool", false, true),
        "V2ListTemplateName" => GhostField.new("V2ListTemplateName", "Text", false, true),
        "Version" => GhostField.new("Version", "Integer", false, true)
      }
    end
    
    def split_id
      ["0x"] + @id[2..-1].scan(/[0-9A-F][1-9A-F]|[1-9A-F][0-9A-F]|00[0-9A-F]{32}/)
    end
    
  end
  
end
