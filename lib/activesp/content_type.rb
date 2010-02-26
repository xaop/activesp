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
      @name = name if name
      @description = description if description
      @version = version if version
      @group = group if group
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
    
    def name
      data["Name"].to_s
    end
    cache :name
    
    def description
      data["Description"].to_s
    end
    cache :description
    
    def version
      data["Version"].to_s
    end
    cache :version
    
    def group
      data["Group"].to_s
    end
    cache :group
    
    def fields
      data.xpath("//sp:Field", NS).map { |field| scope.field(field["ID"]) }.compact
    end
    cache :fields, :dup => true
    
    def attributes
      {
        "Name" => name,
        "ID" => @id,
        "Description" => description,
        "Version" => version,
        "Group" => group
      }
    end
    cache :attributes, :dup => true
    
    def to_s
      "#<ActiveSP::ContentType name=#{name}>"
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
    
    def split_id
      ["0x"] + @id[2..-1].scan(/[0-9A-F][1-9A-F]|[1-9A-F][0-9A-F]|00[0-9A-F]{32}/)
    end
    
  end
  
end
