module ActiveSP
  
  class Site < Base
    
    extend Caching
    extend PersistentCaching
    include Util
    
    attr_reader :url, :connection
    
    persistent { |connection, url, *a| [connection, [:site, url]] }
    def initialize(connection, url, depth = 0)
      @connection, @url, @depth = connection, url, depth
      @services = {}
    end
    
    def relative_url(url = @url)
      url[@connection.root_url.rindex("/") + 1..-1]
    end
    
    def supersite
      if @depth > 0
        Site.new(@connection, File.dirname(@url), @depth - 1)
      end
    end
    cache :supersite
    
    def rootsite
      @depth > 0 ? supersite.rootsite : self
    end
    cache :rootsite
    
    def is_root_site?
      @depth == 0
    end
    
    def key
      encode_key("S", [@url[@connection.root_url.length + 1..-1], @depth])
    end
    
    def sites
      result = call("Webs", "get_web_collection")
      result.xpath("//sp:Web", NS).map { |web| Site.new(connection, web["Url"].to_s, @depth + 1) }
    end
    cache :sites, :dup => true
    
    def site(name)
      result = call("Webs", "get_web", "webUrl" => File.join(@url, name))
      Site.new(connection, result.xpath("//sp:Web", NS).first["Url"].to_s, @depth + 1)
    rescue Savon::SOAPFault
      nil
    end
    
    def lists
      result1 = call("Lists", "get_list_collection")
      result2 = call("SiteData", "get_list_collection")
      result2_by_id = {}
      result2.xpath("//sp:_sList", NS).each do |element|
        data = {}
        element.children.each do |ch|
          data[ch.name] = ch.inner_text
        end
        result2_by_id[data["InternalName"]] = data
      end
      result1.xpath("//sp:List", NS).select { |list| list["Title"] != "User Information List" }.map do |list|
        List.new(self, list["ID"].to_s, list["Title"].to_s, clean_attributes(list.attributes), result2_by_id[list["ID"].to_s])
      end
    end
    cache :lists, :dup => true
    
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
    cache :content_types, :dup => true
    
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
    
    def fields
      call("Webs", "get_columns").xpath("//sp:Field", NS).map do |field|
        attributes = clean_attributes(field.attributes)
        supersite && supersite.field(attributes["ID"].downcase) || Field.new(self, attributes["ID"].downcase, attributes["StaticName"], attributes["Type"], nil, attributes) if attributes["ID"] && attributes["StaticName"]
      end.compact
    end
    cache :fields, :dup => true
    
    def fields_by_name
      fields.inject({}) { |h, f| h[f.attributes["StaticName"]] = f ; h }
    end
    cache :fields_by_name, :dup => true
    
    def field(id)
      fields.find { |f| f.ID == id }
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
    
    def attributes_before_type_cast
      element = data.xpath("//sp:sWebMetadata", NS).first
      result = {}
      element.children.each do |ch|
        result[ch.name] = ch.inner_text
      end
      result
    end
    cache :attributes_before_type_cast
    
    def original_attributes
      type_cast_attributes(self, nil, internal_attribute_types, attributes_before_type_cast)
    end
    cache :original_attributes
    
    def internal_attribute_types
      @@internal_attribute_types ||= {
        "AllowAnonymousAccess" => GhostField.new("AllowAnonymousAccess", "Bool", false, true),
        "AnonymousViewListItems" => GhostField.new("AnonymousViewListItems", "Bool", false, true),
        "Author" => GhostField.new("Author", "InternalUser", false, true),
        "Description" => GhostField.new("Description", "Text", false, true),
        "ExternalSecurity" => GhostField.new("ExternalSecurity", "Bool", false, true),
        "InheritedSecurity" => GhostField.new("InheritedSecurity", "Bool", false, true),
        "IsBucketWeb" => GhostField.new("IsBucketWeb", "Bool", false, true),
        "Language" => GhostField.new("Language", "Integer", false, true),
        "LastModified" => GhostField.new("LastModified", "XMLDateTime", false, true),
        "LastModifiedForceRecrawl" => GhostField.new("LastModifiedForceRecrawl", "XMLDateTime", false, true),
        "Permissions" => GhostField.new("Permissions", "Text", false, true),
        "Title" => GhostField.new("Title", "Text", false, true),
        "UsedInAutocat" => GhostField.new("UsedInAutocat", "Bool", false, true),
        "ValidSecurityInfo" => GhostField.new("ValidSecurityInfo", "Bool", false, true),
        "WebID" => GhostField.new("WebID", "Text", false, true)
      }
    end
    
    def permissions
      result = call("Permissions", "get_permission_collection", "objectName" => File.basename(@url), "objectType" => "Web")
      result.xpath("//spdir:Permission", NS).map do |row|
        accessor = row["MemberIsUser"][/true/i] ? User.new(rootsite, row["UserLogin"]) : Group.new(rootsite, row["GroupName"])
        { :mask => Integer(row["Mask"]), :accessor => accessor }
      end
    end
    cache :permissions, :dup => true
    
    class Service
      
      def initialize(site, name)
        @site, @name = site, name
        @client = Savon::Client.new(File.join(site.url, "_vti_bin", name + ".asmx?WSDL"))
        @client.request.ntlm_auth(site.connection.login, site.connection.password) if site.connection.login
      end
      
      def call(m, *args)
        t1 = Time.now
        if Hash === args[-1]
          body = args.pop
        end
        @client.send(m, *args) do |soap|
          if body
            soap.body = body.inject({}) { |h, (k, v)| h["wsdl:#{k}"] = v ; h }
          end
          yield soap if block_given?
        end
      ensure
        t2 = Time.now
        puts "SP - time: %.3fs, site: %s, service: %s, method: %s, body: %s" % [t2 - t1, @site.url, @name, m, body.inspect] if @site.connection.trace
      end
      
    end
    
  end
  
end
