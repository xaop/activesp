module ActiveSP
  
  class ContentType
    
    include InSite
    include Caching
    
    def initialize(site, list_id, id, name)
      @site, @list_id, @id, @name = site, list_id, id, name
    end
    
    def name
      data["Name"].to_s
    end
    cache :name
    
    def fields
      data.xpath("//sp:Field", NS).map { |field| { :type => field["Type"], :name => field["StaticName"] } }
    end
    cache :fields
    
    def to_s
      "#<ActiveSP::ContentType name=#{name}>"
    end
    
    alias inspect to_s
    
  private
    
    def data
      call("Lists", "get_list_content_type") do |soap|
        soap.body = { "wsdl:listName" => @list_id, "wsdl:contentTypeId" => @id }
      end.xpath("//sp:ContentType", NS).first
    end
    cache :data
    
  end
  
end
