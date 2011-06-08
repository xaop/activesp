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
  
  class ContentType < Base
    
    include InSite
    extend Caching
    extend PersistentCaching
    include Util
    
    # @private
    attr_reader :id
    
    persistent { |site, list, id, *a| [site.connection, [:content_type, id]] }
    # @private
    def initialize(site, list, id, name = nil, description = nil, version = nil, group = nil)
      @site, @list, @id = site, list, id
      @Name = name if name
      @Description = description if description
      @Version = version if version
      @Group = group if group
    end
    
    # Returns the scope of the content type. This can be either a site or a list
    # @return [Site, List]
    def scope
      @list || @site
    end
    
    # Returns the supertype of this content type. This is the content type as defined on the containing
    # site in case this content type has a list as scope. returns nil for a content type that has a site
    # as scope
    # @return [ContentType, nil]
    def supertype
      superkey = split_id[0..-2].join("")
      (@list ? @list.content_type(superkey) : nil) || @site.content_type(superkey)
    end
    cache :supertype
    
    # See {Base#key}
    # @return [String]
    def key
      encode_key("T", [scope.key, @id])
    end
    
    # @private
    def Name
      data["Name"].to_s
    end
    cache :Name
    
    # @private
    def Description
      data["Description"].to_s
    end
    cache :Description
    
    # @private
    def Version
      data["Version"].to_s
    end
    cache :Version
    
    # @private
    def Group
      data["Group"].to_s
    end
    cache :Group
    
    # Returns the list of fields defined for this content type
    # @return [Array<Field>]
    def fields
      data.xpath("//sp:Field", NS).map { |field| scope.field(field["ID"]) }.compact
    end
    cache :fields, :dup => :always
    
    def fields_by_name
      fields.inject({}) { |h, f| h[decode_field_name(f.StaticName)] = f ; h }
    end
    cache :fields_by_name, :dup => :always
    
    # See {Base#save}
    # @return [void]
    def save
      p untype_cast_attributes(@site, nil, internal_attribute_types, changed_attributes)
    end
    
    # @private
    def to_s
      "#<ActiveSP::ContentType Name=#{self.Name}>"
    end
    
    # @private
    alias inspect to_s
    
  private
    
    def data
      if @list
        call("Lists", "GetListContentType", "listName" => @list.id, "contentTypeId" => @id).xpath("//sp:ContentType", NS).first
      else
        call("Webs", "GetContentType", "contentTypeId" => @id).xpath("//sp:ContentType", NS).first
      end
    end
    cache :data
    
    def original_attributes
      type_cast_attributes(@site, nil, internal_attribute_types, clean_item_attributes(data.attributes))
    end
    cache :original_attributes
    
    def internal_attribute_types
      @@internal_attribute_types ||= {
        "Description" => GhostField.new("Description", "Text", false, true),
        "FeatureId" => GhostField.new("FeatureId", "Text", false, true),
        "Group" => GhostField.new("Group", "Text", false, true),
        "Hidden" => GhostField.new("Hidden", "Bool", false, true),
        "ID" => GhostField.new("ID", "Text", false, true),
        "Name" => GhostField.new("Name", "Text", false, true),
        "ReadOnly" => GhostField.new("ReadOnly", "Bool", false, true),
        "Sealed" => GhostField.new("Sealed", "Bool", false, true),
        "V2ListTemplateName" => GhostField.new("V2ListTemplateName", "Text", false, true),
        "Version" => GhostField.new("Version", "Integer", false, true)
      }
    end
    
    def split_id
      ["0x"] + @id[2..-1].scan(/[0-9A-F][1-9A-F]|[1-9A-F][0-9A-F]|00[0-9A-F]{32}/)
    end
    
  end
  
end
