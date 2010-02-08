require 'pp'

module ActiveSP
  
  class List
    
    include InSite
    include Caching
    include Util
    
    attr_reader :site, :id
    
    def initialize(site, id, name = nil, attributes = nil)
      @site, @id = site, id
      @name = name if name
      @attributes = attributes if attributes
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
      clean_list_attributes(data.attributes)
    end
    cache :attributes
    
    def items(options = {})
      folder = options.delete(:folder)
      options.empty? or raise ArgumentError, "unknown options #{options.keys.map { |k| k.inspect }.join(", ")}"
      query_options = Builder::XmlMarkup.new.QueryOptions do |xml|
        xml.Folder(folder.url) if folder
      end
      result = call("Lists", "get_list_items") do |soap|
        soap.body = { "wsdl:listName" => @id, "wsdl:viewFields" => "<ViewFields></ViewFields>", "wsdl:queryOptions" => query_options }
      end
      result.xpath("//z:row", NS).map do |row|
        attributes = clean_item_attributes(fields, row.attributes)
        (attributes["FSObjType"] == "1" ? Folder : Item).new(
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
      data.xpath("//sp:Field", NS).inject({}) { |h, field| h[field["StaticName"]] = Field.new(field["StaticName"], field["Type"], field) ; h }
    end
    cache :fields
    
    def content_types
      result = call("Lists", "get_list_content_types") do |soap|
        soap.body = { "wsdl:listName" => @id }
      end
      result.xpath("//sp:ContentType", NS).map do |content_type|
        ContentType.new(@site, @id, content_type["ID"], content_type["Name"])
      end
    end
    cache :content_types
    
    def to_s
      "#<ActiveSP::List name=#{name}>"
    end
    
    alias inspect to_s
    
  private
    
    def data
      call("Lists", "get_list") { |soap| soap.body = { "wsdl:listName" => @id } }.xpath("//sp:List", NS).first
    end
    cache :data
    
  end
  
end
