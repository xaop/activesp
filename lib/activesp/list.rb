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
      @site, @id = site, id.upcase
      @Title = title if title
      # This testing for emptiness of RootFolder is necessary because it is empty
      # in bulk calls.
      @attributes_before_type_cast1 = attributes_before_type_cast1 if attributes_before_type_cast1
      @attributes_before_type_cast2 = attributes_before_type_cast2 if attributes_before_type_cast2
    end
    
    def RootFolder
      if attributes_before_type_cast1["RootFolder"] == ""
        clear_cache_for("attributes_before_type_cast1")
      end
      attributes_before_type_cast1["RootFolder"]
    end
    
    # The URL of the list
    # @return [String]
    def url
      URL(@site.url).join(self.RootFolder).to_s
    end
    cache :url
    
    # @private
    def relative_url(site = @site.connection.root)
      reference_url = site.url
      reference_url += "/" unless reference_url[-1, 1] == "/"
      url = self.url
      reference_url = reference_url.sub(/\Ahttps?:\/\/[^\/]+/, "")
      url = url.sub(/\Ahttps?:\/\/[^\/]+/, "")
      url[reference_url.length..-1]
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
      def create!(parameters = {})
        @object.create_document!(parameters)
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
      def create!(parameters = {})
        @object.create_folder!(parameters)
      end
    end
    
    # Returns the item with the given name or nil if there is no item with the given name
    # @return [Item]
    def item(name)
      __item(name)
    end
    
    def __item(name, options = {})
      query = Builder::XmlMarkup.new.Query do |xml|
        xml.Where do |xml|
          xml.Eq do |xml|
            xml.FieldRef(:Name => "FileLeafRef")
            xml.Value(name, :Type => "Text")
          end
        end
      end
      items(options.merge(:query => query)).first
    end
    
    alias / item
    
    def create_document(parameters = {})
      when_list { return create_list_item(parameters) }
      when_document_library { return create_library_document(parameters) }
      raise_on_unknown_type
    end
    
    def create_document!(parameters = {})
      create_document(parameters.merge(:override_restrictions => true))
    end
    
    def create_folder(parameters = {})
      name = parameters.delete("FileLeafRef") or raise ArgumentError, "Specify the folder name in the 'FileLeafRef' parameter"
      
      create_list_item(parameters.merge(:folder_name => name))
    end
    
    def create_folder!(parameters = {})
      create_folder(parameters.merge(:override_restrictions => true))
    end
    
    def changes_since_token(token, options = {})
      options = options.dup
      no_preload = options.delete(:no_preload)
      row_limit = (r_l = options.delete(:row_limit)) ? {'rowLimit' => r_l.to_s} : {}
      only_attrs = options.delete(:only_attrs)
      options.empty? or raise ArgumentError, "unknown options #{options.keys.map { |k| k.inspect }.join(", ")}"
      
      if no_preload
        view_fields = Builder::XmlMarkup.new.ViewFields do |xml|
          %w[FSObjType ID UniqueId ServerUrl].each { |f| xml.FieldRef("Name" => f) }
        end
      else
        view_fields = Builder::XmlMarkup.new.ViewFields
      end
      if token
        result = call("Lists", "GetListItemChangesSinceToken", {"listName" => @id, 'queryOptions' => '<queryOptions xmlns:s="http://schemas.microsoft.com/sharepoint/soap/" ><QueryOptions/></queryOptions>', 'changeToken' => token, 'viewFields' => view_fields}.merge(row_limit))
      else
        result = call("Lists", "GetListItemChangesSinceToken", {"listName" => @id, 'queryOptions' => '<queryOptions xmlns:s="http://schemas.microsoft.com/sharepoint/soap/" ><QueryOptions/></queryOptions>', 'viewFields' => view_fields}.merge(row_limit))
      end
      updates = []
      result.xpath("//z:row", NS).each do |row|
        attributes = clean_item_attributes(row.attributes)
        all_attrs = only_attrs ? only_attrs.inject({}) do |h, a|
          if attributes.has_key?(a)
            h[a] = attributes[a]
          end
          h
        end : attributes
        updates << construct_item(:unset, attributes, no_preload ? nil : all_attrs)
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
    
    def create_field(attributes)
      # TODO: remove this in time
      add_to_view = attributes.delete(:add_to_view)
      parameters = ActiveSP::Field.check_attributes_for_creation(@site, attributes)
      fields = Builder::XmlMarkup.new.Fields do |xml|
        xml.Method({ "ID" => "1" }.merge(add_to_view ? { "AddToView" => add_to_view } : {})) do
          xml.Field(parameters)
        end
      end
      result = call("Lists", "UpdateList", "listName" => self.id, "newFields" => fields)
      method = result.xpath("//sp:Method", NS).first
      if error_text = method.xpath("./sp:ErrorText", NS).first
        error_code = method.xpath("./sp:ErrorCode", NS).first.text
        raise ArgumentError.new("#{error_code} : #{error_text.text.to_s}")
      else
        field = method.xpath("./sp:Field", NS).first
        attributes = clean_attributes(field.attributes)
        result = Field.new(self, attributes["ID"].downcase, attributes["StaticName"], attributes["Type"], @site.field(attributes["ID"].downcase), attributes)
        if @fields
          @fields << result
          clear_cache_for(:fields_by_name)
        end
        result
      end
    end
    
    def content_types
      result = call("Lists", "GetListContentTypes", "listName" => @id)
      result.xpath("//sp:ContentType", NS).map do |content_type|
        ContentType.new(@site, self, content_type["ID"], content_type["Name"], content_type["Description"], content_type["Version"], content_type["Group"])
      end
    end
    cache :content_types, :dup => :always
    
    def content_types_by_name
      content_types.inject({}) { |h, t| h[t.Name] = t ; h }
    end
    cache :content_types_by_name, :dup => :always
    
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
    
    def update_attributes(attributes)
      attributes.each do |k, v|
        set_attribute(k, v)
      end
      save
    end
    
    # See {Base#save}
    # @return [void]
    def save
      update_attributes_internal(untype_cast_attributes(@site, nil, internal_attribute_types, changed_attributes, true))
      self
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
    rescue Savon::SOAP::Fault => e
      # This is where it gets ugly... Apparently there is a limit to the number of columns
      # you can retrieve with this operation. Joy!
      if /lookup column threshold/ === e.error_string
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
        rescue Savon::SOAP::Fault => e
          if /lookup column threshold/ === e.error_string
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
    
    def quick_attributes
      type_cast_attributes(@site, nil, internal_attribute_types, attributes_before_type_cast1)
    end
    
  private
    
    def data1
      call("Lists", "GetList", "listName" => @id).xpath("//sp:List", NS).first
    end
    cache :data1
    
    def attributes_before_type_cast1
      clean_attributes(data1.attributes)
    end
    cache :attributes_before_type_cast1
    
    def data2
      call("SiteData", "GetList", "strListName" => @id)
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
      self.RootFolder
      attrs = attributes_before_type_cast1.merge(attributes_before_type_cast2).merge("BaseType" => attributes_before_type_cast1["BaseType"])
      type_cast_attributes(@site, nil, internal_attribute_types, attrs)
    end
    cache :original_attributes
    
    def internal_attribute_types
      @@internal_attribute_types ||= {
        "AllowAnonymousAccess" => GhostField.new("AllowAnonymousAccess", "Bool", false, true, "Allow Anonymous Access?"),
        "AllowDeletion" => GhostField.new("AllowDeletion", "Bool", false, true, "Allow Deletion?"),
        "AllowMultiResponses" => GhostField.new("AllowMultiResponses", "Bool", false, false, "Allow Multiple Responses?"),
        "AnonymousPermMask" => GhostField.new("AnonymousPermMask", "Integer", false, true, "Anonymous Permission Mask"),
        "AnonymousViewListItems" => GhostField.new("AnonymousViewListItems", "Bool", false, true, "Anonymous Can View List Items?"),
        "Author" => GhostField.new("Author", "InternalUser", false, true),
        "BaseTemplate" => GhostField.new("BaseTemplate", "Text", false, true, "Base Template"),
        "BaseType" => GhostField.new("BaseType", "Text", false, true, "Base Type"),
        "Created" => GhostField.new("Created", "StandardDateTime", false, true, "Created"),
        "DefaultViewUrl" => GhostField.new("DefaultViewUrl", "Text", false, true, "Default View Url"),
        "Description" => GhostField.new("Description", "Text", false, false),
        "Direction" => GhostField.new("Direction", "Text", false, false),
        "DocTemplateUrl" => GhostField.new("DocTemplateUrl", "Text", false, true, "Document Template URL"),
        "EmailAlias" => GhostField.new("EmailAlias", "Text", false, true, "Email Alias"),
        "EmailInsertsFolder" => GhostField.new("EmailInsertsFolder", "Text", false, true, "Email Inserts Folder"),
        "EnableAssignedToEmail" => GhostField.new("EnableAssignedToEmail", "Bool", false, false, "Enable Assign to Email?"),
        "EnableAttachments" => GhostField.new("EnableAttachments", "Bool", false, false, "Enable Attachments?"),
        "EnableMinorVersion" => GhostField.new("EnableMinorVersion", "Bool", false, true, "Enable Minor Versions?"),
        "EnableModeration" => GhostField.new("EnableModeration", "Bool", false, false, "Enable Moderation?"),
        "EnableVersioning" => GhostField.new("EnableVersioning", "Bool", false, false, "Enable Versioning?"),
        "EventSinkAssembly" => GhostField.new("EventSinkAssembly", "Text", false, true, "Event Sink Assembly"),
        "EventSinkClass" => GhostField.new("EventSinkClass", "Text", false, true, "Event Sink Class"),
        "EventSinkData" => GhostField.new("EventSinkData", "Text", false, true, "Event Sink Data"),
        "FeatureId" => GhostField.new("FeatureId", "Text", false, true, "Feature ID"),
        "Flags" => GhostField.new("Flags", "Integer", false, true),
        "HasUniqueScopes" => GhostField.new("HasUniqueScopes", "Bool", false, true, "Has Unique Scopes?"),
        "Hidden" => GhostField.new("Hidden", "Bool", false, false),
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
        "MultipleDataList" => GhostField.new("MultipleDataList", "Bool", false, false, "Is Multiple Data List?"),
        "Name" => GhostField.new("Name", "Text", false, true),
        "OnQuickLaunch" => GhostField.new("OnQuickLaunch", "Bool", false, false),
        "Ordered" => GhostField.new("Ordered", "Bool", false, false),
        "Permissions" => GhostField.new("Permissions", "Text", false, true),
        "ReadSecurity" => GhostField.new("ReadSecurity", "Integer", false, true, "Read Security"),
        "RequireCheckout" => GhostField.new("RequireCheckout", "Bool", false, true, "Requires Checkout?"),
        "RootFolder" => GhostField.new("RootFolder", "Text", false, true, "Root Folder"),
        "ScopeId" => GhostField.new("ScopeId", "Text", false, true, "Scope ID"),
        "SendToLocation" => GhostField.new("SendToLocation", "Text", false, true, "Send To Location"),
        "ServerTemplate" => GhostField.new("ServerTemplate", "Text", false, true, "Server Template"),
        "ShowUser" => GhostField.new("ShowUser", "Bool", false, false, "Shows User?"),
        "ThumbnailSize" => GhostField.new("ThumbnailSize", "Integer", false, true, "Thumbnail Size"),
        "Title" => GhostField.new("Title", "Text", false, false),
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
      result = call("Permissions", "GetPermissionCollection", "objectName" => @id, "objectType" => "List")
      rootsite = @site.rootsite
      result.xpath("//spdir:Permission", NS).map do |row|
        accessor = row["MemberIsUser"][/true/i] ? User.new(rootsite, row["UserLogin"]) : Group.new(rootsite, row["GroupName"])
        { :mask => Integer(row["Mask"]), :accessor => accessor }
      end
    end
    cache :permissions, :dup => :always
    
    def get_list_items(view_fields, query_options, query, options = {})
      options = options.dup
      row_limit = (r_l = options.delete(:row_limit)) ? {'rowLimit' => r_l.to_s} : {}
      result = call("Lists", "GetListItems", {"listName" => @id, "viewFields" => view_fields, "queryOptions" => query_options}.merge(query).merge(row_limit))
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
      folder_object = parameters.delete(:folder_object)
      overwrite = parameters.delete(:overwrite)
      override_restrictions = parameters.delete(:override_restrictions)
      file_name = parameters.delete("FileLeafRef") or raise ArgumentError, "Specify the file name in the 'FileLeafRef' parameter"
      if !overwrite
        object = __item(file_name, :folder => folder_object)
        raise ActiveSP::AlreadyExists.new("document with file name #{file_name.inspect} already exists") { object } if object
      end
      destination_urls = Builder::XmlMarkup.new.wsdl(:string, URI.escape(::File.join(folder || url, file_name)))
      parameters = type_check_attributes_for_creation(fields_by_name, parameters, override_restrictions)
      attributes = untype_cast_attributes(@site, self, fields_by_name, parameters, override_restrictions)
      fields = construct_xml_for_copy_into_items(fields_by_name, attributes)
      source_url = escape_xml(file_name)
      result = call("Copy", "CopyIntoItems", "DestinationUrls" => destination_urls, "Stream" => Base64.encode64(content.to_s), "SourceUrl" => source_url, "Fields" => fields)
      copy_result = result.xpath("//sp:CopyResult", NS).first
      error_code = copy_result["ErrorCode"]
      if error_code != "Success"
        raise "#{error_code} : #{copy_result["ErrorMessage"]}"
      else
        __item(file_name, :folder => folder_object)
      end
    end
    
    def create_list_item(parameters)
      parameters = parameters.dup
      folder = parameters.delete(:folder)
      folder_object = parameters.delete(:folder_object)
      folder_name = parameters.delete(:folder_name)
      override_restrictions = parameters.delete(:override_restrictions)
      parameters = type_check_attributes_for_creation(fields_by_name, parameters, override_restrictions)
      attributes = untype_cast_attributes(@site, self, fields_by_name, parameters, override_restrictions)
      folder_attributes = !folder_name && folder ? { "RootFolder" => folder } : {}
      updates = Builder::XmlMarkup.new.Batch(folder_attributes.merge("OnError" => "Continue")) do |xml|
        xml.Method("ID" => 1, "Cmd" => "New") do
          xml.Field("New", "Name" => "ID")
          construct_xml_for_update_list_items(xml, self, fields_by_name, attributes)
          if folder_name
            xml.Field(::File.join(folder || url, folder_name), "Name" => "FileRef")
            xml.Field(1, "Name" => "FSObjType")
          else
            xml.Field(0, "Name" => "FSObjType")
          end
        end
      end
      result = call("Lists", "UpdateListItems", "listName" => self.id, "updates" => updates)
      create_result = result.xpath("//sp:Result", NS).first
      error_text = create_result.xpath("./sp:ErrorText", NS).first
      if !error_text
        row = result.xpath("//z:row", NS).first
        construct_item(nil, clean_item_attributes(row.attributes), nil)
      else
        error_code = create_result.xpath("./sp:ErrorCode", NS).first
        error_code &&= error_code.text.to_s
        if error_code == "0x8107090d"
          raise ActiveSP::AlreadyExists.new(error_text.text.to_s) { (folder_object || self).item(folder_name) }
        else
          # Make it look like the error came from soap
          # Alternatively we could wrap all the soap faults maybe
          raise ArgumentError.new(error_text.text.to_s)
        end
      end
    end
    
    def update_attributes_internal(attributes)
      properties = Builder::XmlMarkup.new.List(attributes)
      call("Lists", "UpdateList", "listName" => self.id, "listProperties" => properties)
      reload
    end
    
  end
  
end
