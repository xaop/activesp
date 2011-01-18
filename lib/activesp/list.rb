# Copyright (c) 2010 XAOP bvba
# 
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# 
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# 
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

module ActiveSP
  
  class List < Base
    
    include InSite
    extend Caching
    extend PersistentCaching
    include Util
    
    # The containing site
    # @return [Site]
    attr_reader :site
    # The ID of the list
    # @return [String]
    attr_reader :id
    
    persistent { |site, id, *a| [site.connection, [:list, id]] }
    # @private
    def initialize(site, id, title = nil, attributes_before_type_cast1 = nil, attributes_before_type_cast2 = nil)
      @site, @id = site, id
      @Title = title if title
      # This testing for emptiness of RootFolder is necessary because it is empty
      # in bulk calls.
      @attributes_before_type_cast1 = attributes_before_type_cast1 if attributes_before_type_cast1 && attributes_before_type_cast1["RootFolder"] != ""
      @attributes_before_type_cast2 = attributes_before_type_cast2 if attributes_before_type_cast2 && attributes_before_type_cast2["RootFolder"] != ""
    end
    
    # The URL of the list
    # @return [String]
    def url
      URL(@site.url).join(attributes["RootFolder"]).to_s
      # # Dirty. Used to use RootFolder, but if you get the data from the bulk calls, RootFolder is the empty
      # # string rather than what it should be. That's what you get with web services as an afterthought I guess.
      # view_url = ::File.dirname(attributes["DefaultViewUrl"])
      # result = URL(@site.url).join(view_url).to_s
      # if ::File.basename(result) == "Forms" and dir = ::File.dirname(result) and dir.length > @site.url.length
      #   result = dir
      # end
      # result
    end
    cache :url
    
    # @private
    def relative_url
      @site.relative_url(url)
    end
    
    # See {Base#key}
    # @return [String]
    def key
      encode_key("L", [@site.key, @id])
    end
    
    # @private
    def Title
      data1["Title"].to_s
    end
    cache :Title
    
    # Yields the items in this list according to the given options. Note that this method does not
    # recurse into folders. I believe specifying a folder of '' actually does recurse
    # @param [Hash] options Options
    # @option options [Folder, :all] :folder (nil) The folder to search in
    # @option options [String] :query (nil) The query to execute as an XML fragment
    # @option options [Boolean] :no_preload (nil) If set to true, the attributes are not preloaded. Can be more efficient if you only need the list of items and not their attributes
    # @yieldparam [Item] item
    def each_item(options = {})
      options = options.dup
      folder = options.delete(:folder)
      # Always include a query because for some reason SP is capable of not finding certain
      # items otherwise.
      # query = { "query" => options.delete(:query) || "<Query><Where></Where></Query>" }
      query = { "query" => options.delete(:query) || "" }
      no_preload = options.delete(:no_preload)
      options.empty? or raise ArgumentError, "unknown options #{options.keys.map { |k| k.inspect }.join(", ")}"
      query_options = Builder::XmlMarkup.new.QueryOptions do |xml|
        xml.Folder(folder == :all ? "" : folder.url) if folder
      end
      if no_preload
        view_fields = Builder::XmlMarkup.new.ViewFields do |xml|
          %w[FSObjType ID UniqueId ServerUrl].each { |f| xml.FieldRef("Name" => f) }
        end
        get_list_items(view_fields, query_options, query) do |attributes|
          yield construct_item(folder, attributes, nil)
        end
      else
        __each_item(query_options, query) do |attributes|
          yield construct_item(folder, attributes, attributes)
        end
      end
    end
    association :items
    
    def each_document(parameters = {}, &blk)
      query = Builder::XmlMarkup.new.Query do |xml|
        xml.Where do |xml|
          xml.Neq do |xml|
            xml.FieldRef(:Name => "FSObjType")
            xml.Value(1, :Type => "Text")
          end
        end
      end
      each_item(parameters.merge(:query => query), &blk)
    end
    association :documents do
      def create(parameters = {})
        @object.create_document(parameters)
      end
    end
    
    def each_folder(parameters = {}, &blk)
      query = Builder::XmlMarkup.new.Query do |xml|
        xml.Where do |xml|
          xml.Eq do |xml|
            xml.FieldRef(:Name => "FSObjType")
            xml.Value(1, :Type => "Text")
          end
        end
      end
      each_item(parameters.merge(:query => query), &blk)
    end
    association :folders do
      def create(parameters = {})
        @object.create_folder(parameters)
      end
    end
    
    # Returns the item with the given name or nil if there is no item with the given name
    # @return [Item]
    def item(name)
      query = Builder::XmlMarkup.new.Query do |xml|
        xml.Where do |xml|
          xml.Eq do |xml|
            xml.FieldRef(:Name => "FileLeafRef")
            xml.Value(name, :Type => "Text")
          end
        end
      end
      items(:query => query).first
    end
    
    alias / item
    
    def create_document(parameters = {})
      when_list { return create_list_item(parameters) }
      when_document_library { return create_library_document(parameters) }
      raise_on_unknown_type
    end
    
    def create_folder(parameters = {})
      name = parameters.delete("FileLeafRef") or raise ArgumentError, "Specify the folder name in the 'FileLeafRef' parameter"
      
      create_list_item(parameters.merge(:folder_name => name))
    end
    
    def changes_since_token(token, options = {})
      options = options.dup
      no_preload = options.delete(:no_preload)
      options.empty? or raise ArgumentError, "unknown options #{options.keys.map { |k| k.inspect }.join(", ")}"
      
      if no_preload
        view_fields = Builder::XmlMarkup.new.ViewFields do |xml|
          %w[FSObjType ID UniqueId ServerUrl].each { |f| xml.FieldRef("Name" => f) }
        end
      else
        view_fields = Builder::XmlMarkup.new.ViewFields
      end
      result = call("Lists", "get_list_item_changes_since_token", "listName" => @id, 'queryOptions' => '<queryOptions xmlns:s="http://schemas.microsoft.com/sharepoint/soap/" ><QueryOptions/></queryOptions>', 'changeToken' => token, 'viewFields' => view_fields)
      updates = []
      result.xpath("//z:row", NS).each do |row|
        attributes = clean_item_attributes(row.attributes)
        updates << construct_item(:unset, attributes, no_preload ? nil : attributes)
      end
      deletes = []
      result.xpath("//sp:Changes/sp:Id", NS).each do |row|
        if row["ChangeType"].to_s == "Delete"
          deletes << encode_key("I", [key, row.text.to_s])
        end
      end
      new_token = result.xpath("//sp:Changes", NS).first["LastChangeToken"].to_s
      { :updates => updates, :deletes => deletes, :new_token => new_token }
    end
    
    def fields
      data1.xpath("//sp:Field", NS).map do |field|
        attributes = clean_attributes(field.attributes)
        if attributes["ID"] && attributes["StaticName"]
          Field.new(self, attributes["ID"].downcase, attributes["StaticName"], attributes["Type"], @site.field(attributes["ID"].downcase), attributes)
        end
      end.compact
    end
    cache :fields, :dup => :always
    
    def fields_by_name
      fields.inject({}) { |h, f| h[decode_field_name(f.attributes["StaticName"])] = f ; h }
    end
    cache :fields_by_name, :dup => :always
    
    # @private
    def field(id)
      fields.find { |f| f.ID == id }
    end
    
    def content_types
      result = call("Lists", "get_list_content_types", "listName" => @id)
      result.xpath("//sp:ContentType", NS).map do |content_type|
        ContentType.new(@site, self, content_type["ID"], content_type["Name"], content_type["Description"], content_type["Version"], content_type["Group"])
      end
    end
    cache :content_types, :dup => :always
    
    # @private
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
    
    # See {Base#save}
    # @return [void]
    def save
      p untype_cast_attributes(@site, nil, internal_attribute_types, changed_attributes)
    end
    
    # @private
    def to_s
      "#<ActiveSP::List Title=#{self.Title}>"
    end
    
    # @private
    alias inspect to_s
    
    # @private
    def when_document_library
      yield if %w[1].include?(attributes["BaseType"])
    end
    
    # @private
    def when_list
      yield if %w[0 5].include?(attributes["BaseType"])
    end
    
    # @private
    def raise_on_unknown_type
      base_type = attributes["BaseType"]
      raise "not yet BaseType = #{base_type.inspect}" unless %w[0 1 5].include?(base_type)
    end
    
    # @private
    def __each_item(query_options, query)
      get_list_items("<ViewFields></ViewFields>", query_options, query) do |attributes|
        yield attributes
      end
    rescue Savon::SOAPFault => e
      # This is where it gets ugly... Apparently there is a limit to the number of columns
      # you can retrieve with this operation. Joy!
      if e.message[/lookup column threshold/]
        fields = self.fields.map { |f| f.Name }
        split_factor = 2
        begin
          split_size = (fields.length + split_factor - 1) / split_factor
          parts = []
          split_factor.times do |i|
            lo = i * split_size
            hi = [(i + 1) * split_size, fields.length].min - 1
            view_fields = Builder::XmlMarkup.new.ViewFields do |xml|
              fields[lo..hi].each { |f| xml.FieldRef("Name" => f) }
            end
            by_id = {}
            get_list_items(view_fields, query_options, query) do |attributes|
              by_id[attributes["ID"]] = attributes
            end
            parts << by_id
          end
          parts[0].each do |id, attrs|
            parts[1..-1].each do |part|
              attrs.merge!(part[id])
            end
            yield attrs
          end
        rescue Savon::SOAPFault => e
          if e.message[/lookup column threshold/]
            split_factor += 1
            retry
          else
            raise
          end
        end
      else
        raise
      end
    end
    
    def ==(object)
      ::ActiveSP::List === object && self.ID == object.ID
    end
    
  private
    
    def data1
      call("Lists", "get_list", "listName" => @id).xpath("//sp:List", NS).first
    end
    cache :data1
    
    def attributes_before_type_cast1
      clean_attributes(data1.attributes)
    end
    cache :attributes_before_type_cast1
    
    def data2
      call("SiteData", "get_list", "strListName" => @id)
    end
    cache :data2
    
    def attributes_before_type_cast2
      element = data2.xpath("//sp:sListMetadata", NS).first
      result = {}
      element.children.each do |ch|
        result[ch.name] = ch.inner_text
      end
      result
    end
    cache :attributes_before_type_cast2
    
    def original_attributes
      attrs = attributes_before_type_cast1.merge(attributes_before_type_cast2).merge("BaseType" => attributes_before_type_cast1["BaseType"])
      type_cast_attributes(@site, nil, internal_attribute_types, attrs)
    end
    cache :original_attributes
    
    def internal_attribute_types
      @@internal_attribute_types ||= {
        "AllowAnonymousAccess" => GhostField.new("AllowAnonymousAccess", "Bool", false, true, "Allow Anonymous Access?"),
        "AllowDeletion" => GhostField.new("AllowDeletion", "Bool", false, true, "Allow Deletion?"),
        "AllowMultiResponses" => GhostField.new("AllowMultiResponses", "Bool", false, true, "Allow Multiple Responses?"),
        "AnonymousPermMask" => GhostField.new("AnonymousPermMask", "Integer", false, true, "Anonymous Permission Mask"),
        "AnonymousViewListItems" => GhostField.new("AnonymousViewListItems", "Bool", false, true, "Anonymous Can View List Items?"),
        "Author" => GhostField.new("Author", "InternalUser", false, true),
        "BaseTemplate" => GhostField.new("BaseTemplate", "Text", false, true, "Base Template"),
        "BaseType" => GhostField.new("BaseType", "Text", false, true, "Base Type"),
        "Created" => GhostField.new("Created", "StandardDateTime", false, true, "Created"),
        "DefaultViewUrl" => GhostField.new("DefaultViewUrl", "Text", false, true, "Default View Url"),
        "Description" => GhostField.new("Description", "Text", false, false),
        "Direction" => GhostField.new("Direction", "Text", false, true),
        "DocTemplateUrl" => GhostField.new("DocTemplateUrl", "Text", false, true, "Document Template URL"),
        "EmailAlias" => GhostField.new("EmailAlias", "Text", false, true, "Email Alias"),
        "EmailInsertsFolder" => GhostField.new("EmailInsertsFolder", "Text", false, true, "Email Inserts Folder"),
        "EnableAssignedToEmail" => GhostField.new("EnableAssignedToEmail", "Bool", false, true, "Enable Assign to Email?"),
        "EnableAttachments" => GhostField.new("EnableAttachments", "Bool", false, true, "Enable Attachments?"),
        "EnableMinorVersion" => GhostField.new("EnableMinorVersion", "Bool", false, true, "Enable Minor Versions?"),
        "EnableModeration" => GhostField.new("EnableModeration", "Bool", false, true, "Enable Moderation?"),
        "EnableVersioning" => GhostField.new("EnableVersioning", "Bool", false, true, "Enable Versioning?"),
        "EventSinkAssembly" => GhostField.new("EventSinkAssembly", "Text", false, true, "Event Sink Assembly"),
        "EventSinkClass" => GhostField.new("EventSinkClass", "Text", false, true, "Event Sink Class"),
        "EventSinkData" => GhostField.new("EventSinkData", "Text", false, true, "Event Sink Data"),
        "FeatureId" => GhostField.new("FeatureId", "Text", false, true, "Feature ID"),
        "Flags" => GhostField.new("Flags", "Integer", false, true),
        "HasUniqueScopes" => GhostField.new("HasUniqueScopes", "Bool", false, true, "Has Unique Scopes?"),
        "Hidden" => GhostField.new("Hidden", "Bool", false, true),
        "ID" => GhostField.new("ID", "Text", false, true),
        "ImageUrl" => GhostField.new("ImageUrl", "Text", false, true, "Image URL"),
        "InheritedSecurity" => GhostField.new("InheritedSecurity", "Bool", false, true, "Has Inherited Security?"),
        "InternalName" => GhostField.new("InternalName", "Text", false, true, "Internal Name"),
        "ItemCount" => GhostField.new("ItemCount", "Integer", false, true, "Item Count"),
        "LastDeleted" => GhostField.new("LastDeleted", "StandardDateTime", false, true, "Deleted"),
        "LastModified" => GhostField.new("LastModified", "XMLDateTime", false, true, "Modified"),
        "LastModifiedForceRecrawl" => GhostField.new("LastModifiedForceRecrawl", "XMLDateTime", false, true, "Last Modified Force Recrawl"),
        "MajorVersionLimit" => GhostField.new("MajorVersionLimit", "Integer", false, true, "Major Version Limit"),
        "MajorWithMinorVersionsLimit" => GhostField.new("MajorWithMinorVersionsLimit", "Integer", false, true, "Major With Minor Versions Limit"),
        "MobileDefaultViewUrl" => GhostField.new("MobileDefaultViewUrl", "Text", false, true, "Mobile Default View URL"),
        "Modified" => GhostField.new("Modified", "StandardDateTime", false, true),
        "MultipleDataList" => GhostField.new("MultipleDataList", "Bool", false, true, "Is Multiple Data List?"),
        "Name" => GhostField.new("Name", "Text", false, true),
        "Ordered" => GhostField.new("Ordered", "Bool", false, true),
        "Permissions" => GhostField.new("Permissions", "Text", false, true),
        "ReadSecurity" => GhostField.new("ReadSecurity", "Integer", false, true, "Read Security"),
        "RequireCheckout" => GhostField.new("RequireCheckout", "Bool", false, true, "Requires Checkout?"),
        "RootFolder" => GhostField.new("RootFolder", "Text", false, true, "Root Folder"),
        "ScopeId" => GhostField.new("ScopeId", "Text", false, true, "Scope ID"),
        "SendToLocation" => GhostField.new("SendToLocation", "Text", false, true, "Send To Location"),
        "ServerTemplate" => GhostField.new("ServerTemplate", "Text", false, true, "Server Template"),
        "ShowUser" => GhostField.new("ShowUser", "Bool", false, true, "Shows User?"),
        "ThumbnailSize" => GhostField.new("ThumbnailSize", "Integer", false, true, "Thumbnail Size"),
        "Title" => GhostField.new("Title", "Text", false, true),
        "ValidSecurityInfo" => GhostField.new("ValidSecurityInfo", "Bool", false, true, "Has Valid Security Info?"),
        "Version" => GhostField.new("Version", "Integer", false, true),
        "WebFullUrl" => GhostField.new("WebFullUrl", "Text", false, true, "Full Web URL"),
        "WebId" => GhostField.new("WebId", "Text", false, true, "Web ID"),
        "WebImageHeight" => GhostField.new("WebImageHeight", "Integer", false, true, "Web Image Height"),
        "WebImageWidth" => GhostField.new("WebImageWidth", "Integer", false, true, "Web Image Width"),
        "WorkFlowId" => GhostField.new("WorkFlowId", "Text", false, true, "Work Flow ID"),
        "WriteSecurity" => GhostField.new("WriteSecurity", "Integer", false, true, "Write Security")
      }
    end
    
    def permissions
      result = call("Permissions", "get_permission_collection", "objectName" => @id, "objectType" => "List")
      rootsite = @site.rootsite
      result.xpath("//spdir:Permission", NS).map do |row|
        accessor = row["MemberIsUser"][/true/i] ? User.new(rootsite, row["UserLogin"]) : Group.new(rootsite, row["GroupName"])
        { :mask => Integer(row["Mask"]), :accessor => accessor }
      end
    end
    cache :permissions, :dup => :always
    
    def get_list_items(view_fields, query_options, query)
      result = call("Lists", "get_list_items", { "listName" => @id, "viewFields" => view_fields, "queryOptions" => query_options }.merge(query))
      result.xpath("//z:row", NS).each do |row|
        yield clean_item_attributes(row.attributes)
      end
    end
    
    def construct_item(folder, attributes, all_attributes)
      (attributes["FSObjType"][/1$/] ? Folder : Item).new(
        self,
        attributes["ID"],
        folder == :all ? :unset : folder,
        attributes["UniqueId"],
        attributes["ServerUrl"],
        all_attributes
      )
    end
    
    def create_library_document(parameters)
      parameters = parameters.dup
      content = parameters.delete(:content) or raise ArgumentError, "Specify the content in the :content parameter"
      folder = parameters.delete(:folder)
      overwrite = parameters.delete(:overwrite)
      file_name = parameters.delete("FileLeafRef") or raise ArgumentError, "Specify the file name in the 'FileLeafRef' parameter"
      raise ArgumentError, "document with file name #{file_name.inspect} already exists" if item(file_name) && !overwrite
      destination_urls = Builder::XmlMarkup.new.wsdl(:string, URI.escape(::File.join(folder || url, file_name)))
      parameters = type_check_attributes_for_creation(fields_by_name, parameters)
      attributes = untype_cast_attributes(@site, self, fields_by_name, parameters)
      fields = construct_xml_for_copy_into_items(fields_by_name, attributes)
      source_url = escape_xml(file_name)
      result = call("Copy", "copy_into_items", "DestinationUrls" => destination_urls, "Stream" => Base64.encode64(content.to_s), "SourceUrl" => source_url, "Fields" => fields)
      copy_result = result.xpath("//sp:CopyResult", NS).first
      error_code = copy_result["ErrorCode"]
      if error_code != "Success"
        raise "#{error_code} : #{copy_result["ErrorMessage"]}"
      else
        item(file_name)
      end
    end
    
    def create_list_item(parameters)
      parameters = parameters.dup
      folder = parameters.delete(:folder)
      folder_name = parameters.delete(:folder_name)
      parameters = type_check_attributes_for_creation(fields_by_name, parameters)
      attributes = untype_cast_attributes(@site, self, fields_by_name, parameters)
      updates = Builder::XmlMarkup.new.Batch("OnError" => "Continue", "ListVersion" => 1) do |xml|
        xml.Method("ID" => 1, "Cmd" => "New") do
          xml.Field("New", "Name" => "ID")
          construct_xml_for_update_list_items(xml, fields_by_name, attributes)
          if folder_name
            xml.Field(::File.join(folder || url, folder_name), "Name" => "FileRef")
            xml.Field(1, "Name" => "FSObjType")
          else
            xml.Field(::File.join(folder, Time.now.strftime("%Y%m%d%H%M%S-#{rand(16**3).to_s(16)}")), "Name" => "FileRef") if folder
          end
        end
      end
      result = call("Lists", "update_list_items", "listName" => self.id, "updates" => updates)
      create_result = result.xpath("//sp:Result", NS).first
      error_text = create_result.xpath("./sp:ErrorText", NS).first
      if !error_text
        row = result.xpath("//z:row", NS).first
        construct_item(nil, clean_item_attributes(row.attributes), nil)
      else
        raise "cannot create item: #{error_text.text.to_s}"
      end
    end
    
  end
  
end
