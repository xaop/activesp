module ActiveSP
  
  class Folder
    
    include InSite
    include Caching
    include Util
    
    def initialize(list, id, uid, url = nil, attributes = nil)
      @list, @id, @uid = list, id, uid
      @site = list.site
      @url = url if url
      @attributes = attributes if attributes
    end
    
    def id
      @uid
    end
    
    def url
      URL.new(@list.url).join(attributes["ServerUrl"]).to_s
    end
    cache :url
    
    def key
      encode_key("F", [@list.key, @id, @uid])
    end
    
    def attributes
      clean_item_attributes(@list.fields, data.attributes)
    end
    cache :attributes
    
    def items
      @list.items(:folder => url)
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
