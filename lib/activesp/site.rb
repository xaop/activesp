require 'nokogiri'

module ActiveSP
  
  NS = {
    "sp" => "http://schemas.microsoft.com/sharepoint/soap/",
    "z" => "#RowsetSchema",
    "spdir" => "http://schemas.microsoft.com/sharepoint/soap/directory/"
  }
  
  class Site < Base
    
    include Caching
    include Util
    
    attr_reader :url, :connection, :depth
    
    def initialize(connection, url, depth = 0)
      @connection, @url, @depth = connection, url, depth
      @services = {}
    end
    
    def supersite
      if depth > 0
        Site.new(@connection, File.dirname(@url), depth - 1)
      end
    end
    
    def key
      encode_key("S", [@url, @depth])
    end
    
    def sites
      result = call("Webs", "get_web_collection")
      result.xpath("//sp:Web", NS).map { |web| Site.new(connection, web["Url"].to_s, @depth + 1) }
    end
    cache :sites
    
    def lists
      result = call("Lists", "get_list_collection")
      result.xpath("//sp:List", NS).select { |list| list["Title"] != "User Information List" }.map { |list| List.new(self, list["ID"].to_s, list["Title"].to_s, clean_list_attributes(list.attributes)) }
    end
    cache :lists
    
    def content_types
      result = call("Webs", "get_content_types", "listName" => @id)
      result.xpath("//sp:ContentType", NS).map do |content_type|
        ContentType.new(self, nil, content_type["ID"], content_type["Name"], content_type["Description"], content_type["Version"], content_type["Group"])
      end
    end
    cache :content_types
    
    def to_s
      "#<ActiveSP::Site url=#{@url.inspect}>"
    end
    
    alias inspect to_s
    
  private
    
    def call(service, m, *args, &blk)
      result = service(service).call(m, *args, &blk)
      Nokogiri::XML.parse(result.http.body)
    end
    
    def fetch(url)
      @connection.fetch(url)
    end
  
    def service(name)
      @services[name] ||= Service.new(self, name)
    end
    
    def data
      call("SiteData", "get_site")
    end
    cache :data
    
    class Service
      
      def initialize(site, name)
        @site, @name = site, name
        @client = Savon::Client.new(File.join(site.url, "_vti_bin", name + ".asmx?WSDL"))
        @client.request.ntlm_auth(site.connection.login, site.connection.password) if site.connection.login
      end
      
      def call(m, *args)
        if Hash === args[-1]
          body = args.pop
        end
        @client.send(m, *args) do |soap|
          if body
            soap.body = body.inject({}) { |h, (k, v)| h["wsdl:#{k}"] = v ; h }
          end
          yield soap if block_given?
        end
      end
      
    end
    
  end
  
end
