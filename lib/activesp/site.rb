require 'nokogiri'
require 'time'

module ActiveSP
  
  class Site < Base
    
    extend Caching
    extend PersistentCaching
    include Util
    
    attr_reader :url, :connection, :depth
    
    persistent { |connection, url, *a| [connection, [:site, url]] }
    def initialize(connection, url, depth = 0)
      @connection, @url, @depth = connection, url, depth
      @services = {}
    end
    
    def relative_url(url = @url)
      url[@connection.root_url.rindex("/") + 1..-1]
    end
    
    def supersite
      if depth > 0
        Site.new(@connection, File.dirname(@url), depth - 1)
      end
    end
    cache :supersite
    
    def rootsite
      depth > 0 ? supersite.rootsite : self
    end
    cache :rootsite
    
    def key
      encode_key("S", [@url[@connection.root_url.length + 1..-1], @depth])
    end
    
    def attributes_before_type_cast
      element = data.xpath("//sp:sWebMetadata", NS).first
      result = {}
      element.children.each do |ch|
        result[ch.name] = ch.inner_text
      end
      result
    end
    cache :attributes_before_type_cast
    
    def attributes
      attrs = attributes_before_type_cast.dup
      %w[AllowAnonymousAccess AnonymousViewListItems ExternalSecurity InheritedSecurity IsBucketWeb UsedInAutocat ValidSecurityInfo].each do |attr|
        attrs[attr] = !!attrs[attr][/true/i]
      end
      %w[LastModified LastModifiedForceRecrawl].each do |attr|
        if attrs[attr] == "0001-01-01T00:00:00"
          attrs[attr] = nil
        else
          attrs[attr] = Time.xmlschema(attrs[attr])
        end
      end
      attrs["Author"] = User.new(rootsite, attrs["Author"][/\\/] ? attrs["Author"] : "SHAREPOINT\\system")
      attrs["Language"] = Integer(attrs["Language"])
      attrs
    end
    cache :attributes
    
    def sites
      result = call("Webs", "get_web_collection")
      result.xpath("//sp:Web", NS).map { |web| Site.new(connection, web["Url"].to_s, @depth + 1) }
    end
    cache :sites
    
    def site(name)
      result = call("Webs", "get_web", "webUrl" => File.join(@url, name))
      Site.new(connection, result.xpath("//sp:Web", NS).first["Url"].to_s, @depth + 1)
    rescue Savon::SOAPFault
      nil
    end
    
    def lists
      result = call("Lists", "get_list_collection")
      result.xpath("//sp:List", NS).select { |list| list["Title"] != "User Information List" }.map { |list| List.new(self, list["ID"].to_s, list["Title"].to_s) }
    end
    cache :lists
    
    def list(name)
      lists.find { |list| File.basename(list.attributes["RootFolder"]) == name }
    end
    
    def /(name)
      list(name) || site(name)
    end
    
    def content_types
      result = call("Webs", "get_content_types", "listName" => @id)
      result.xpath("//sp:ContentType", NS).map do |content_type|
        supersite && supersite.content_type(content_type["ID"]) || ContentType.new(self, nil, content_type["ID"], content_type["Name"], content_type["Description"], content_type["Version"], content_type["Group"])
      end
    end
    cache :content_types
    
    def content_type(id)
      content_types.find { |t| t.id == id }
    end
    
    def permission_set
      if attributes["InheritedSecurity"]
        supersite.permission_set
      else
        PermissionSet.new(self)
      end
    end
    cache :permission_set
    
    def permissions
      result = call("Permissions", "get_permission_collection", "objectName" => File.basename(@url), "objectType" => "Web")
      result.xpath("//spdir:Permission", NS).map do |row|
        accessor = row["MemberIsUser"][/true/i] ? User.new(rootsite, row["UserLogin"]) : Group.new(rootsite, row["GroupName"])
        { :mask => row["Mask"].to_i, :accessor => accessor }
      end
    end
    cache :permissions
    
    def fields
      call("Webs", "get_columns").xpath("//sp:Field", NS).map do |field|
        attributes = field.attributes.inject({}) { |h, (k, v)| h[k] = v.to_s ; h }
        supersite && supersite.field(attributes["ID"]) || Field.new(self, attributes["ID"], attributes["StaticName"], attributes["Type"], attributes) if attributes["ID"] && attributes["StaticName"]
      end.compact
    end
    cache :fields
    
    def fields_by_name
      fields.inject({}) { |h, f| h[f.attributes["StaticName"]] = f ; h }
    end
    cache :fields_by_name
    
    def field(id)
      fields.find { |f| f.id == id }
    end
    
    def to_s
      "#<ActiveSP::Site url=#{@url}>"
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
      call("SiteData", "get_web")
    end
    cache :data
    
    class Service
      
      def initialize(site, name)
        @site, @name = site, name
        @client = Savon::Client.new(File.join(site.url, "_vti_bin", name + ".asmx?WSDL"))
        @client.request.ntlm_auth(site.connection.login, site.connection.password) if site.connection.login
      end
      
      def call(m, *args)
        # puts "Calling site: #{@site.url}, service: #{@name}, method: #{m}, args: #{args.inspect}"
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
