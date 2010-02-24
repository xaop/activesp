require 'pp'

module ActiveSP
  
  class List < Base
    
    include InSite
    extend Caching
    extend PersistentCaching
    include Util
    
    attr_reader :site, :id
    
    persistent { |site, id, *a| [site.connection, [:list, id]] }
    def initialize(site, id, name = nil, attributes_before_type_cast = nil)
      @site, @id = site, id
      @name = name if name
      @attributes_before_type_cast = attributes_before_type_cast if attributes_before_type_cast
    end
    
    def url
      URL(@site.url).join(attributes["RootFolder"]).to_s
    end
    
    def relative_url
      @site.relative_url(url)
    end
    
    def key
      encode_key("L", [@site.key, @id])
    end
    
    def name
      data["Title"].to_s
    end
    cache :name
    
    def attributes
      attrs = attributes_before_type_cast.merge(attributes_before_type_cast2).merge("BaseType" => attributes_before_type_cast["BaseType"])
      %w[
        AllowAnonymousAccess AllowMultiResponses AnonymousViewListItems EnableAttachments
        EnableMinorVersion EnableModeration EnableVersioning HasUniqueScopes Hidden InheritedSecurity
        MultipleDataList Ordered RequireCheckout ShowUser ValidSecurityInfo
      ].each do |attr|
        attrs[attr] = !!attrs[attr][/true/i]
      end
      %w[Created LastDeleted Modified].each do |attr|
        attrs[attr] = Time.parse(attrs[attr])
      end
      %w[LastModified LastModifiedForceRecrawl].each do |attr|
        if attrs[attr] == "0001-01-01T00:00:00"
          attrs[attr] = nil
        else
          attrs[attr] = Time.xmlschema(attrs[attr])
        end
      end
      %w[AnonymousPermMask Flags ItemCount MajorVersionLimit MajorWithMinorVersionsLimit Version ReadSecurity ThumbnailSize WebImageHeight WebImageWidth WriteSecurity].each do |attr|
        attrs[attr] = Integer(attrs[attr]) unless attrs[attr].nil? || attrs[attr] == ""
      end
      attrs["Author"] = User.new(@site.rootsite, attrs["Author"][/\\/] ? attrs["Author"] : "SHAREPOINT\\system")
      attrs
    end
    cache :attributes
    
    def attributes_before_type_cast
      clean_list_attributes(data.attributes)
    end
    cache :attributes_before_type_cast
    
    def attributes_before_type_cast2
      element = data2.xpath("//sp:sListMetadata", NS).first
      result = {}
      element.children.each do |ch|
        result[ch.name] = ch.inner_text
      end
      result
    end
    cache :attributes_before_type_cast2
    
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
    
    def item(name)
      query = Builder::XmlMarkup.new.Query do |xml|
        xml.Where do |xml|
          xml.Eq do |xml|
            xml.FieldRef(:Name => "FileLeafRef")
            xml.Value(name, :Type => "String")
          end
        end
      end
      items(:query => query).first
    end
    
    def /(name)
      item(name)
    end
    
    def fields
      data.xpath("//sp:Field", NS).map do |field|
        attributes = field.attributes.inject({}) { |h, (k, v)| h[k] = v.to_s ; h }
        @site.field(attributes["ID"]) || Field.new(self, attributes["ID"], attributes["StaticName"], attributes["Type"], attributes) if attributes["ID"] && attributes["StaticName"]
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
    
    def content_types
      result = call("Lists", "get_list_content_types", "listName" => @id)
      result.xpath("//sp:ContentType", NS).map do |content_type|
        ContentType.new(@site, self, content_type["ID"], content_type["Name"], content_type["Description"], content_type["Version"], content_type["Group"])
      end
    end
    cache :content_types
    
    def content_type(id)
      content_types.find { |t| t.id == id }
    end
    
    def permission_set
      if attributes["InheritedSecurity"]
        @site.permission_set
      else
        PermissionSet.new(self)
      end
    end
    cache :permission_set
    
    def permissions
      result = call("Permissions", "get_permission_collection", "objectName" => @id, "objectType" => "List")
      rootsite = @site.rootsite
      result.xpath("//spdir:Permission", NS).map do |row|
        accessor = row["MemberIsUser"][/true/i] ? User.new(rootsite, row["UserLogin"]) : Group.new(rootsite, row["GroupName"])
        { :mask => row["Mask"].to_i, :accessor => accessor }
      end
    end
    cache :permissions
    
    def to_s
      "#<ActiveSP::List name=#{name}>"
    end
    
    alias inspect to_s
    
  private
    
    def data
      call("Lists", "get_list", "listName" => @id).xpath("//sp:List", NS).first
    end
    cache :data
    
    def data2
      call("SiteData", "get_list", "strListName" => @id)
    end
    cache :data2
    
  end
  
end
