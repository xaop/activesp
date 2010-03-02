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
    
    def attributes
      type_cast_attributes(@list, @list.fields_by_name, attributes_before_type_cast)
    end
    cache :attributes, :dup => true
    
    def attributes_before_type_cast
      clean_item_attributes(data.attributes)
    end
    cache :attributes_before_type_cast, :dup => true
    
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
    
    def versions
      call("Versions", "get_versions", "fileName" => attributes["ServerUrl"])
    end
    
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
    
    def type_cast_attributes(list, fields, attributes)
      attributes.inject({}) do |h, (k, v)|
        if field = fields[k]
          case field.type
          when "DateTime"
            Time.parse(v)
          when "Computed", "Text", "Guid", "ContentTypeId", "URL"
          when "Integer", "Counter", "Attachments"
            v = v.to_i
          when "ModStat" # 0
          when "Number"
            v = v.to_f
          when "Boolean"
            v = v == "1"
          when "File"
            # v = v.sub(/\A.*?;#/, "")
          when "Note"
          
          when "User"
            d = split_multi(v)
            v = User.new(@site.connection.root, d[2][/\\/] ? d[2] : "SHAREPOINT\\system")
          when "UserMulti"
            d = split_multi(v)
            v = (0...(d.length / 4)).map { |i| User.new(@site.connection.root, d[4 * i + 2][/\\/] ? d[4 * i + 2] : "SHAREPOINT\\system") }
          
          when "Choice"
            # For some reason there is no encoding here
          when "MultiChoice"
            # SharePoint disallows ;# inside choices and starts with a ;#
            v = v.split(/;#/)[1..-1]
          
          when "Lookup"
            d = split_multi(v)
            if field.list_for_lookup
              v = create_item_from_id(field.list_for_lookup, d[0])
            else
              v = d[2]
            end
          when "LookupMulti"
            d = split_multi(v)
            if field.list_for_lookup
              v = (0...(d.length / 4)).map { |i| create_item_from_id(field.list_for_lookup, d[4 * i]) }
            else
              v = (0...(d.length / 4)).map { |i| d[4 * i + 2] }
            end
          
          else
            # raise NotImplementedError, "don't know type #{field.type.inspect} for #{k}=#{v.inspect}"
            warn "don't know type #{field.type.inspect} for #{k}=#{v.inspect}"
          end
        else
          # raise ArgumentError, "can't find field #{k.inspect}"
          warn "can't find field #{k.inspect}"
        end
        h[k] = v
        h
      end
    end
    
  end
  
end
