require 'pp'

module ActiveSP
  
  class List < Base
    
    include InSite
    include Caching
    include Util
    
    attr_reader :site, :id
    
    def initialize(site, id, name = nil, attributes_before_type_cast = nil)
      @site, @id = site, id
      @name = name if name
      @attributes_before_type_cast = attributes_before_type_cast if attributes_before_type_cast
    end
    
    def url
      URL(@site.url).join(attributes["RootFolder"]).to_s
    end
    
    def key
      encode_key("L", [@site.key, @id])
    end
    
    def name
      data["Title"].to_s
    end
    cache :name
    
    def attributes
      attributes_before_type_cast
    end
    cache :attributes
    
    def attributes_before_type_cast
      clean_list_attributes(data.attributes)
    end
    cache :attributes_before_type_cast
    
    def items(options = {})
      folder = options.delete(:folder)
      query = options.delete(:query)
      query = query ? { "query" => query } : {}
      options.empty? or raise ArgumentError, "unknown options #{options.keys.map { |k| k.inspect }.join(", ")}"
      query_options = Builder::XmlMarkup.new.QueryOptions do |xml|
        xml.Folder(folder.url) if folder
      end
      result = call("Lists", "get_list_items", { "listName" => @id, "viewFields" => "<ViewFields></ViewFields>", "queryOptions" => query_options }.merge(query))
      result.xpath("//z:row", NS).map do |row|
        attributes = clean_item_attributes(row.attributes)
        (attributes["FSObjType"][/1$/] ? Folder : Item).new(
          self,
          attributes["ID"],
          folder,
          attributes["UniqueId"],
          attributes["ServerUrl"],
          attributes
        )
      end
    end
    
    def fields
      data.xpath("//sp:Field", NS).inject({}) { |h, field| h[field["StaticName"]] = Field.new(self, field["StaticName"], field["Type"], field) ; h }
    end
    cache :fields
    
    def content_types
      result = call("Lists", "get_list_content_types", "listName" => @id)
      result.xpath("//sp:ContentType", NS).map do |content_type|
        ContentType.new(@site, self, content_type["ID"], content_type["Name"], content_type["Description"], content_type["Version"], content_type["Group"])
      end
    end
    cache :content_types
    
    def to_s
      "#<ActiveSP::List name=#{name}>"
    end
    
    alias inspect to_s
    
  private
    
    def data
      call("Lists", "get_list", "listName" => @id).xpath("//sp:List", NS).first
    end
    cache :data
    
  end
  
end
