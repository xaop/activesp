require 'nokogiri'

module ActiveSP
  
  NS = {
    "sp" => "http://schemas.microsoft.com/sharepoint/soap/",
    "z" => "#RowsetSchema"
  }
  
  class Site
    
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
      result.xpath("//sp:List", NS).map { |list| List.new(self, list["ID"].to_s, list["Title"].to_s, clean_list_attributes(list.attributes)) }
    end
    cache :lists
    
    def to_s
      "#<ActiveSP::Site url=#{@url.inspect}>"
    end
    
    alias inspect to_s
    
  private
    
    def call(service, m, *args, &blk)
      result = service(service).call(m, *args, &blk)
      Nokogiri::XML.parse(result.http.body)
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
      
      def call(m, *args, &blk)
        @client.send(m, *args, &blk)
      end
      
    end
    
  end
  
end
