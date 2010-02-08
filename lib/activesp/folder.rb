module ActiveSP
  
  class Folder
    
    include InSite
    include Caching
    include Util
    
    attr_reader :list
    
    def initialize(list, id, folder, uid = nil, url = nil, attributes = nil)
      @list, @id, @folder = list, id, folder
      @uid = uid if uid
      @site = list.site
      @url = url if url
      @attributes = attributes if attributes
    end
    
    def parent
      @folder || @list
    end
    
    def id
      @uid
    end
    
    def uid
      attributes["UniqueID"]
    end
    cache :uid
    
    def url
      URL(@list.url).join(attributes["ServerUrl"]).to_s
    end
    cache :url
    
    def key
      encode_key("F", [parent.key, @id])
    end
    
    def attributes
      clean_item_attributes(@list.fields, data.attributes)
    end
    cache :attributes
    
    def items
      @list.items(:folder => self)
    end
    
    def to_s
      "#<ActiveSP::Folder url=#{url}>"
    end
    
    alias inspect to_s
    
  private
    
    def data
      query_options = Builder::XmlMarkup.new.QueryOptions
      query = Builder::XmlMarkup.new.Query do |xml|
        xml.Where do |xml|
          xml.Eq do |xml|
            xml.FieldRef(:Name => "ID")
            xml.Value(@id, :Type => "Counter")
          end
        end
      end
      result = call("Lists", "get_list_items") do |soap|
        soap.body = { "wsdl:listName" => @list.id, "wsdl:viewFields" => "<ViewFields></ViewFields>", "wsdl:queryOptions" => query_options, "wsdl:query" => query }
      end
      result.xpath("//z:row", NS).first
    end
    cache :data
    
  end
  
end
