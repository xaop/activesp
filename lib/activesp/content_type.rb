module ActiveSP
  
  class ContentType < Base
    
    include InSite
    include Caching
    include Util
    
    def initialize(site, list, id, name = nil, description = nil, version = nil, group = nil)
      @site, @list, @id = site, list, id
      @name = name if name
      @description = description if description
      @version = version if version
      @group = group if group
    end
    
    def key
      encode_key("T", [(@list || @site).key, @id])
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
      data.xpath("//sp:Field", NS).map { |field| Field.new(@list, field["StaticName"], field["Type"], field) }
    end
    cache :fields
    
    def attributes
      {
        "Name" => name,
        "ID" => @id,
        "Description" => description,
        "Version" => version,
        "Group" => group
      }
    end
    cache :attributes
    
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
    
  end
  
end
