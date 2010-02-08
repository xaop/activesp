module ActiveSP
  
  class Item
    
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
      encode_key("I", [parent.key, @id])
    end
    
    def attributes
      clean_item_attributes(@list.fields, data.attributes)
    end
    cache :attributes
    
    def attachments
      result = call("Lists", "get_attachment_collection") do |soap|
        soap.body = { "wsdl:listName" => @list.id, "wsdl:listItemID" => @id }
      end
      result.xpath("//sp:Attachment", NS).map { |att| att.text }
    end
    cache :attachments
    
    def content_urls
      case @list.attributes["BaseType"]
      when "0"
        attachments
      when "1"
        [url]
      else
        raise "not yet BaseType = #{@list.attributes["BaseType"].inspect}"
      end
    end
    cache :content_urls
    
    def to_s
      "#<ActiveSP::Item url=#{url}>"
    end
    
    alias inspect to_s
    
  private
    
    def data
      query_options = Builder::XmlMarkup.new.QueryOptions do |xml|
        xml.Folder
      end
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
