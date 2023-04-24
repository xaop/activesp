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
  class Site < Base
    extend Caching
    extend PersistentCaching
    include Util

    # The URL of this site
    # @return [String]
    attr_reader :url # TODO: deprecate this in favor of Url
    # @private
    attr_reader :connection

    persistent { |connection, url, *a| [connection, [:site, url]] }
    # @private
    def initialize(connection, url, depth = 0)
      @connection, @url, @depth = connection, url, depth
      @services = {}
    end

    def Url
      @url
    end

    def Name
      ::File.basename(@url)
    end

    # Returns the containing site, or nil if this is the root site
    # @return [Site]
    def supersite
      unless is_root_site?
        Site.new(@connection, ::File.dirname(@url), @depth - 1)
      end
    end
    cache :supersite

    # Returns the root site, or this site if it is the root site
    # @return [Site]
    def rootsite
      is_root_site? ? self : supersite.rootsite
    end
    cache :rootsite

    # Returns true if this site is the root site
    # @return [Boolean]
    def is_root_site?
      @depth == 0
    end

    # See {Base#key}
    # @return [String]
    def key # This documentation is not ideal. The ideal doesn't work out of the box
      encode_key("S", [@url[@connection.root_url.sub(/\/\z/, "").length + 1..-1], @depth])
    end

    def each_site(&blk)
      __sites.each(&blk)
    end
    association :sites do
      def create(attributes)
        @object.create_site(attributes)
      end
    end

    # Returns the site with the given name. This name is what appears in the URL as name and is immutable. Return nil
    # if such a site does not exist
    # @param [String] name The name if the site
    # @return [Site]
    def site(name)
      result = call("Webs", "GetWeb", "webUrl" => ::File.join(@url, name))
      Site.new(connection, result.xpath("//sp:Web", NS).first["Url"].to_s, @depth + 1)
    rescue Savon::SOAPFault
      nil
    end

    def create_site(attributes)
      template = attributes.delete("Template")
      ActiveSP::SiteTemplate === template or raise ArgumentError, "wrong type for Template attribute"
      title = attributes.delete("Title")
      title or raise ArgumentError, "wrong type for Title attribute"
      title = title.to_s
      lcid = attributes.delete("Language")
      Integer === lcid or raise ArgumentError, "wrong type for Language attribute"
      type_check_attributes_for_creation(fields_by_name, attributes, false)
      result = call("Meetings", "CreateWorkspace", "title" => title, "templateName" => template.Name, "lcid" => lcid)
      Site.new(connection, result.xpath("//meet:CreateWorkspace", NS).first["Url"].to_s, @depth + 1)
    end

    def each_list(&blk)
      __lists.each(&blk)
    end
    association :lists do
      def create(attributes)
        @object.create_list(attributes)
      end
    end

    # Returns the list with the given name. The name is what appears in the URL as name and is immutable. Returns nil
    # if such a list does not exist
    # @param [String] name The name of the list
    # @return [List]
    def list(name)
      lists.find { |list| ::File.basename(list.url) == name }
    end

    def create_list(attributes)
      template = attributes.delete("ServerTemplate")
      ActiveSP::ListTemplate === template or raise ArgumentError, "wrong type for ServerTemplate attribute"
      title = attributes.delete("Title")
      title or raise ArgumentError, "wrong type for Title attribute"
      title = title.to_s
      description = attributes.delete("Description").to_s
      type_check_attributes_for_creation(fields_by_name, attributes, false)
      result = call("Lists", "AddList", "listName" => title, "description" => description, "templateID" => template.Type)
      list = result.xpath("//sp:List", NS).first
      List.new(self, list["ID"].to_s, list["Title"].to_s, clean_attributes(list.attributes))
    end

    # Returns the site or list with the given name, or nil if it does not exist
    # @param [String] name The name of the site or list
    # @return [Site, List]
    def /(name)
      list(name) || site(name)
    end

    # Returns the list of content types defined for this site. These include the content types defined on
    # containing sites as they are automatically inherited
    # @return [Array<ContentType>]
    def content_types
      result = call("Webs", "GetContentTypes", "listName" => @id)
      result.xpath("//sp:ContentType", NS).map do |content_type|
        supersite && supersite.content_type(content_type["ID"]) || ContentType.new(self, nil, content_type["ID"], content_type["Name"], content_type["Description"], content_type["Version"], content_type["Group"])
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

    # Returns the permission set associated with this site. This returns the permission set of
    # the containing site if it does not have a permission set of its own
    # @return [PermissionSet]
    def permission_set
      if attributes["InheritedSecurity"]
        supersite.permission_set
      else
        PermissionSet.new(self)
      end
    end
    cache :permission_set

    # Returns the list of fields for this site. This includes fields inherited from containing sites
    # @return [Array<Field>]
    def fields
      call("Webs", "GetColumns").xpath("//sp:Field", NS).map do |field|
        attributes = clean_attributes(field.attributes)
        supersite && supersite.field(attributes["ID"].downcase) || Field.new(self, attributes["ID"].downcase, attributes["StaticName"], attributes["Type"], nil, attributes, extract_custom_props(field)) if attributes["ID"] && attributes["StaticName"]
      end.compact
    end
    cache :fields, :dup => :always

    # Returns the result of {Site#fields} hashed by name
    # @return [Hash{String => Field}]
    def fields_by_name
      fields.inject({}) { |h, f| h[f.attributes["StaticName"]] = f ; h }
    end
    cache :fields_by_name, :dup => :always

    # @private
    def field(id)
      fields.find { |f| f.ID == id }
    end

    def update_attributes(attributes)
      attributes.each do |k, v|
        set_attribute(k, v)
      end
      save
    end

    # See {Base#save}
    # @return [void]
    def save
      update_attributes_internal(untype_cast_attributes(self, nil, internal_attribute_types, changed_attributes, false))
      self
    end

    def accessible?
      data
      true
    rescue Savon::HTTPError
      false
    end

    def destroy
      call("Dws", "DeleteDws")
      supersite.__unregister_site(self)
      self
    end

    # @private
    def to_s
      "#<ActiveSP::Site url=#{@url}>"
    end

    # @private
    alias inspect to_s

    #private
    def __unregister_site(site)
      p [:__unregister_site, self]
      @__sites.delete(site) if @__sites
    end

    def quick_attributes
      {
        "Name" => self.Name,
        "Url" => self.Url
      }
    end

  private

    def call(service, m, *args, &blk)
      result = connection.with_sts_auth_retry do |retried|
        if retried
          @services.delete(service)
        end
        service(service).call(m, *args, &blk)
      end
      Nokogiri::XML.parse(result.http.body)
    end

    def fetch(url)
      @connection.fetch(url)
    end

    def service(name)
      @services[name] ||= Service.new(self, name)
    end

    def data
      # Looks like you can't call this as a non-admin. To investigate further
      call("SiteData", "GetWeb")
    rescue Savon::HTTPError
      # This can fail when you don't have access to this site
      call("Webs", "GetWeb", "webUrl" => ".")
    end
    cache :data

    def attributes_before_type_cast
      if element = data.xpath("//sp:sWebMetadata", NS).first
        result = {}
        element.children.each do |ch|
          result[ch.name] = ch.inner_text
        end
        result.merge("Url" => @url, "Name" => self.Name)
      else
        element = data.xpath("//sp:Web", NS).first
        clean_attributes(element.attributes).merge("Url" => @url, "Name" => self.Name)
      end
    end
    cache :attributes_before_type_cast

    def original_attributes
      type_cast_attributes(self, nil, internal_attribute_types, attributes_before_type_cast)
    end
    cache :original_attributes

    def internal_attribute_types
      @@internal_attribute_types ||= {
        "AllowAnonymousAccess" => GhostField.new("AllowAnonymousAccess", "Bool", false, true, "Allow Anonymous Access?"),
        "AnonymousViewListItems" => GhostField.new("AnonymousViewListItems", "Bool", false, true, "Anonymous Can View List Items?"),
        "Author" => GhostField.new("Author", "InternalUser", false, true),
        "Description" => GhostField.new("Description", "Text", false, true),
        "ExternalSecurity" => GhostField.new("ExternalSecurity", "Bool", false, true, "Has External Security?"),
        "InheritedSecurity" => GhostField.new("InheritedSecurity", "Bool", false, true, "Has Inherited Security?"),
        "IsBucketWeb" => GhostField.new("IsBucketWeb", "Bool", false, true, "Is Bucket Web?"),
        "Language" => GhostField.new("Language", "Integer", false, true),
        "LastModified" => GhostField.new("LastModified", "XMLDateTime", false, true, "Modified"),
        "LastModifiedForceRecrawl" => GhostField.new("LastModifiedForceRecrawl", "XMLDateTime", false, true, "Last Modified Force Recrawl"),
        "Name" => GhostField.new("Name", "Text", false, true),
        "Permissions" => GhostField.new("Permissions", "Text", false, true),
        "Title" => GhostField.new("Title", "Text", false, false),
        "Url" => GhostField.new("Url", "Text", false, true),
        "UsedInAutocat" => GhostField.new("UsedInAutocat", "Bool", false, true, "Used in Autocat?"),
        "ValidSecurityInfo" => GhostField.new("ValidSecurityInfo", "Bool", false, true, "Has Valid Security Info?"),
        "WebID" => GhostField.new("WebID", "Text", false, true, "Web ID")
      }
    end

    def permissions
      result = call("Permissions", "GetPermissionCollection", "objectName" => ::File.basename(@url), "objectType" => "Web")
      result.xpath("//spdir:Permission", NS).map do |row|
        accessor = row["MemberIsUser"][/true/i] ? User.new(rootsite, row["UserLogin"]) : Group.new(rootsite, row["GroupName"])
        { :mask => Integer(row["Mask"]), :accessor => accessor }
      end
    end
    cache :permissions, :dup => :always

    def update_attributes_internal(attributes)
      call("Dws", "RenameDws", "title" => attributes["Title"])
      reload
    end

    def __sites
      result = call("Webs", "GetWebCollection")
      result.xpath("//sp:Web", NS).map { |web| Site.new(connection, web["Url"].to_s, @depth + 1) }
    end
    cache :__sites, :dup => :always

    def __lists
      result1 = call("Lists", "GetListCollection")
      result2 = call("SiteData", "GetListCollection")
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
    cache :__lists, :dup => :always

    # @private
    class Service
      class ServiceXmlBuilder
        def initialize(body)
          @body = body
        end

        def to_s
          if @body
            @body.map do |k, v|
              Builder::XmlMarkup.new.wsdl(k.to_sym) { |e| e << v.to_s }
            end.join
          else
            ""
          end
        end
      end

      def initialize(site, name)
        @site, @name = site, name
        wsdl_uri = ::File.join(URI.escape(site.url), "_vti_bin", name + ".asmx?WSDL")
        authentication_options = site.connection.authentication_options
        @client = Savon::Client.new(authentication_options.merge(wsdl: wsdl_uri, namespace_identifier: :wsdl, log: false))
      end

      def call(m, *args)
        t1 = Time.now
        if Hash === args[-1]
          body = args.pop
        end
        @client.call(m.snakecase.to_sym, *args, message: ServiceXmlBuilder.new(body)) do |soap|
          raise "Block not really supported here" if block_given?
          #yield soap if block_given?
        end
      rescue Savon::SOAPFault => e
        if e.error_code == 0x80004005
          raise ActiveSP::AccessDenied, "access denied"
        elsif e.error_code == 0x80070005
          raise ActiveSP::PermissionDenied, "permission denied"
        else
          raise e
        end
      ensure
        t2 = Time.now
        puts "SP - time: %.3fs, site: %s, service: %s, method: %s, body: %s" % [t2 - t1, @site.url, @name, m, body.inspect] if @site.connection.trace
      end
    end
  end
end
