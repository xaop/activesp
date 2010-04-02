module ActiveSP
  
  class Item < Base
    
    include InSite
    extend Caching
    include Util
    
    attr_reader :list
    
    def initialize(list, id, folder, uid = nil, url = nil, attributes_before_type_cast = nil)
      @list, @id, @folder = list, id, folder
      @uid = uid if uid
      @site = list.site
      @url = url if url
      @attributes_before_type_cast = attributes_before_type_cast if attributes_before_type_cast
    end
    
    def parent
      @folder || @list
    end
    
    def id
      uid
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
    
    def attachments
      result = call("Lists", "get_attachment_collection", "listName" => @list.id, "listItemID" => @id)
      result.xpath("//sp:Attachment", NS).map { |att| att.text }
    end
    cache :attachments, :dup => true
    
    def content_urls
      case @list.attributes["BaseType"]
      when "0", "5"
        attachments
      when "1"
        [url]
      else
        raise "not yet BaseType = #{@list.attributes["BaseType"].inspect}"
      end
    end
    cache :content_urls, :dup => true
    
    def content_type
      ContentType.new(@site, @list, attributes["ContentTypeId"])
    end
    cache :content_type
    
    # def versions
    #   call("Versions", "get_versions", "fileName" => attributes["ServerUrl"])
    # end
    
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
      result = call("Lists", "get_list_items", "listName" => @list.id, "viewFields" => "<ViewFields></ViewFields>", "queryOptions" => query_options, "query" => query)
      result.xpath("//z:row", NS).first
    end
    cache :data
    
    def attributes_before_type_cast
      clean_item_attributes(data.attributes)
    end
    cache :attributes_before_type_cast
    
    def original_attributes
      type_cast_attributes(@site, @list, @list.fields_by_name, attributes_before_type_cast)
    end
    cache :original_attributes
    
    def internal_attribute_types
      list.fields_by_name
    end
    
  end
  
end
