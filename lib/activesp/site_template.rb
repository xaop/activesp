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
  class SiteTemplate < Base
    extend Caching
    extend PersistentCaching
    include Util

    attr_reader :Name

    persistent { |connection, name, *a| [connection, [:template, name]] }
    # @private
    def initialize(connection, name, attributes_before_type_cast)
      @connection, @Name, @attributes_before_type_cast = connection, name, attributes_before_type_cast
    end

    def key
      encode_key("MS", [@Name])
    end

    # @private
    def to_s
      "#<ActiveSP::Template name=#{self.Name}>"
    end

    # @private
    alias inspect to_s

  private

    def original_attributes
      @original_attributes ||= type_cast_attributes(@site, nil, internal_attribute_types, @attributes_before_type_cast)
    end

    def internal_attribute_types
      @@internal_attribute_types ||= {
        "Description" => GhostField.new("Description", "Text", false, true),
        "DisplayCategory" => GhostField.new("DisplayCategory", "Text", false, true),
        "HasProvisionClass" => GhostField.new("HasProvisionClass", "Bool", false, true),
        "ID" => GhostField.new("ID", "Integer", false, true),
        "ImageUrl" => GhostField.new("ImageUrl", "Text", false, true),
        "IsCustom" => GhostField.new("IsCustom", "Bool", false, true),
        "IsHidden" => GhostField.new("IsHidden", "Bool", false, true),
        "IsRootWebOnly" => GhostField.new("IsRootWebOnly", "Bool", false, true),
        "IsSubWebOnly" => GhostField.new("IsSubWebOnly", "Bool", false, true),
        "IsUnique" => GhostField.new("IsUnique", "Bool", false, true),
        "Name" => GhostField.new("Name", "Text", false, true),
        "Title" => GhostField.new("Title", "Text", false, true)
      }
    end
  end
end
