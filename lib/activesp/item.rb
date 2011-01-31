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
  
  class Item < Base
    
    include InSite
    extend Caching
    include Util
    
    # Returns the list in which the item is located
    # @return [List]
    attr_reader :list
    
    # @private
    def initialize(list, id, folder = :unset, uid = nil, url = nil, attributes_before_type_cast = nil)
      @list, @id = list, id
      @folder = folder if folder != :unset # We have to allow for nil
      @uid = uid if uid
      @site = list.site
      @url = url if url
      @attributes_before_type_cast = attributes_before_type_cast if attributes_before_type_cast
    end
    
    def ID
      @id
    end
    
    def is_folder?
      false
    end
    
    # Returns the folder, if any, that this item is located in.
    # @return [Folder, nil]
    def folder
      query = Builder::XmlMarkup.new.Query do |xml|
        xml.Where do |xml|
          xml.Eq do |xml|
            xml.FieldRef(:Name => "FileRef")
            xml.Value(::File.dirname(url).sub(/\A\//, ""), :Type => "Text")
          end
          xml.Eq do |xml|
            xml.FieldRef(:Name => "FSObjType")
            xml.Value(1, :Type => "Text")
          end
        end
      end
      @list.items(:folder => :all, :query => query).first
    end
    cache :folder
    
    # Returns the parent of this item.
    # @return [Folder, List]
    def parent
      folder || @list
    end
    
    # @private
    def id
      uid
    end
    
    # @private
    def uid
      attributes["UniqueID"]
    end
    cache :uid
    
    # The URL of this item
    # @return [String]
    def url
      # URL(@list.url).join(attributes["ServerUrl"]).to_s
      attributes["ServerUrl"]
    end
    cache :url
    
    def absolute_url
      URL(@list.url).join(attributes["ServerUrl"]).to_s
    end
    cache :absolute_url
    
    # See {Base#key}
    # @return [String]
    def key
      encode_key("I", [@list.key, @id])
    end
    
    # Returns a list of the URLs of the attachments of this item. Note that for items in a document
    # library, this returns an empty list
    # @return [Array<String>]
    def attachment_urls
      @list.when_list do
        result = call("Lists", "get_attachment_collection", "listName" => @list.id, "listItemID" => @id)
        return result.xpath("//sp:Attachment", NS).map { |att| att.text }
      end
      @list.when_document_library { raise TypeError, "a document library does not support attachments" }
      @list.raise_on_unknown_type
    end
    cache :attachment_urls, :dup => :always
    
    # Yields each attachment as a ActiveSP::File object.
    # 
    def each_attachment
      attachment_urls.each { |url| yield ActiveSP::File.new(self, url, true) }
    end
    
    def add_attachment(parameters = {})
      @list.when_list do
        parameters = parameters.dup
        content = parameters.delete(:content) or raise ArgumentError, "Specify the content in the :content parameter"
        file_name = parameters.delete(:file_name) or raise ArgumentError, "Specify the file name in the :file_name parameter"
        result = call("Lists", "add_attachment", "listName" => @list.ID, "listItemID" => self.ID, "fileName" => file_name, "attachment" => Base64.encode64(content.to_s))
        add_result = result.xpath("//sp:AddAttachmentResult", NS).first
        if add_result
          clear_cache_for(:attachment_urls)
          return ActiveSP::File.new(self, add_result.text, true)
        else
          raise "cannot add attachment"
        end
      end
      @list.when_document_library { raise TypeError, "a document library does not support attachments" }
      @list.raise_on_unknown_type
    end
    
    association :attachments do
      def create(parameters = {})
        @object.add_attachment(parameters)
      end
    end
    
    def content
      @list.when_list { raise TypeError, "a list has attachments" }
      @list.when_document_library { return ActiveSP::File.new(self, url, false) }
      @list.raise_on_unknown_type
    end
    
    def content=(data)
      @list.when_list { raise TypeError, "a list has attachments" }
      @list.when_document_library { @list.create_document(:overwrite => true, :content => data, "FileLeafRef" => original_attributes["FileLeafRef"]) }
      @list.raise_on_unknown_type
    end
    
    # Returns a list of the content URLs for this item. For items in document libraries, this
    # returns the url, for other items this returns the attachments. These URLs can be used
    # to download all contents. See {Connection#fetch}
    # @return [Array<String>]
    def content_urls
      @list.when_list { return attachment_urls }
      @list.when_document_library { return is_folder? ? [] : [url] }
      @list.raise_on_unknown_type
    end
    cache :content_urls, :dup => :always
    
    # Returns the content type of this item
    # @return [ContentType]
    def content_type
      ContentType.new(@site, @list, attributes["ContentTypeId"])
    end
    cache :content_type
    
    # def versions
    #   call("Versions", "get_versions", "fileName" => attributes["ServerUrl"])
    # end
    
    # See {Base#save}
    # @return [self]
    def save
      update_attributes_internal(untype_cast_attributes(@site, nil, internal_attribute_types, changed_attributes))
      self
    end
    
    def check_out
      @list.when_list { raise TypeError, "cannot check out list items; they would disappear" }
      @list.raise_on_unknown_type
      result = call("Lists", "check_out_file", "pageUrl" => absolute_url, "checkoutToLocal" => false)
      checkout_result = result.xpath("//sp:CheckOutFileResult", NS).first.text
      if checkout_result == "true"
        self
      else
        raise "cannot check out this item"
      end
    end
    
    def check_in(options = {})
      options = options.dup
      type = options.delete(:type) or raise ArgumentError, ":type parameter not specified"
      comment = options.delete(:comment)
      options.empty? or raise ArgumentError, "unsupported options #{options.keys.map { |k| k.inspect }.join(", ")}"
      @list.when_list { raise TypeError, "cannot check in list items because you can't check them out" }
      @list.raise_on_unknown_type
      if checkin_type = { :minor => 0, :major => 1, :overwrite => 2 }[type]
        if type == :minor && !@list.attribute("EnableMinorVersion")
          raise TypeError, "this list does not support minor versions"
        end
        result = call("Lists", "check_in_file", "pageUrl" => absolute_url, "comment" => comment, "CheckinType" => checkin_type)
        checkin_result = result.xpath("//sp:CheckInFileResult", NS).first.text
        if checkin_result == "true"
          self
        else
          raise "cannot check in this item"
        end
      else
        raise ArgumentError, "invalid checkin type #{type.inspect}, valid values are :minor, :major and :overwrite"
      end
    end
    
    def cancel_checkout
      @list.when_list { raise TypeError, "cannot undo check-out for list items because you can't check them out" }
      @list.raise_on_unknown_type
      result = call("Lists", "undo_check_out", "pageUrl" => absolute_url)
      cancel_result = result.xpath("//sp:UndoCheckOutResult", NS).first.text
      if cancel_result == "true"
        self
      else
        raise "cannot cancel check-out for this item"
      end
    end
    
    def update_attributes(attributes)
      attributes.each do |k, v|
        set_attribute(k, v)
      end
      save
    end
    
    def destroy
      updates = Builder::XmlMarkup.new.Batch("OnError" => "Continue", "ListVersion" => 1) do |xml|
        xml.Method("ID" => 1, "Cmd" => "Delete") do
          xml.Field(self.ID, "Name" => "ID")
        end
      end
      result = call("Lists", "update_list_items", "listName" => @list.id, "updates" => updates)
      create_result = result.xpath("//sp:Result", NS).first
      error_code = create_result.xpath("./sp:ErrorCode", NS).first.text.to_i(0)
      if error_code == 0
        @ID = nil
      else
        message = create_result.xpath("./sp:ErrorText", NS).first
        message &&= message.text
        raise "cannot destroy item, error code = #{error_code}, error description = #{message}"
      end
      self
    end
    
    # @private
    def to_s
      "#<ActiveSP::Item url=#{url}>"
    end
    
    # @private
    alias inspect to_s
    
    def ==(object)
      ::ActiveSP::List === object && self.ID == object.ID
    end
    
  private
    
    def raw_attributes
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
      @list.__each_item(query_options, "query" => query) do |attributes|
        return attributes
      end
    end
    cache :raw_attributes
    
    def attributes_before_type_cast
      clean_item_attributes(raw_attributes)
    end
    cache :attributes_before_type_cast
    
    def original_attributes
      type_cast_attributes(@site, @list, @list.fields_by_name, attributes_before_type_cast)
    end
    cache :original_attributes
    
    def internal_attribute_types
      # list.fields_by_name
      content_type.fields_by_name
    end
    cache :internal_attribute_types
    
    def update_attributes_internal(attributes)
      attributes = attributes.dup
      if file_leaf_ref = attributes.delete("FileLeafRef")
        base_name = ::File.basename(file_leaf_ref, ".*")
      end
      updates = Builder::XmlMarkup.new.Batch("OnError" => "Continue", "ListVersion" => @list.attribute("Version")) do |xml|
        xml.Method("ID" => 1, "Cmd" => "Update") do
          xml.Field(self.ID, "Name" => "ID")
          construct_xml_for_update_list_items(xml, @list.fields_by_name, attributes)
          xml.Field(base_name, "Name" => "BaseName") if base_name
          xml.Field(URI.escape(original_attributes["ServerFileRef"]), "Name" => "FileRef")
        end
      end
      result = call("Lists", "update_list_items", "listName" => @list.id, "updates" => updates)
      create_result = result.xpath("//sp:Result", NS).first
      error_code = create_result.xpath("./sp:ErrorCode", NS).first.text.to_i(0)
      puts updates
      if error_code == 0
        row = result.xpath("//z:row", NS).first
        @attributes_before_type_cast = clean_item_attributes(row.attributes)
        reload
      else
        message = create_result.xpath("./sp:ErrorText", NS).first
        message &&= message.text
        raise "cannot update item, error code = #{error_code}, error description = #{message}"
      end
    end
    
  end
  
end
