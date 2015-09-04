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
  
  class ListTemplate < Base
    
    extend Caching
    extend PersistentCaching
    include Util
    
    attr_reader :Type
    
    persistent { |connection, type, *a| [connection, [:template, type]] }
    # @private
    def initialize(connection, type, attributes_before_type_cast)
      @connection, @Type, @attributes_before_type_cast = connection, type, attributes_before_type_cast
    end
    
    def key
      encode_key("ML", [@Type])
    end
    
    # @private
    def to_s
      "#<ActiveSP::Template type=#{self.Type}>"
    end
    
    # @private
    alias inspect to_s
    
  private
    
    def original_attributes
      @original_attributes ||= type_cast_attributes(@site, nil, internal_attribute_types, @attributes_before_type_cast)
    end
    
    def internal_attribute_types
      @@internal_attribute_types ||= {
        "BaseType" => GhostField.new("BaseType", "Text", false, true),
        "Description" => GhostField.new("Description", "Text", false, true),
        "DisplayName" => GhostField.new("DisplayName", "Text", false, true),
        "DocumentTemplate" => GhostField.new("DocumentTemplate", "Integer", false, true),
        "DontSaveInTemplate" => GhostField.new("DontSaveInTemplate", "Bool", false, true),
        "FeatureId" => GhostField.new("FeatureId", "Text", false, true),
        "HiddenList" => GhostField.new("HiddenList", "Bool", false, true),
        "Image" => GhostField.new("Image", "Text", false, true),
        "FolderCreation" => GhostField.new("FolderCreation", "Bool", false, true),
        "Hidden" => GhostField.new("Hidden", "Bool", false, true),
        "OnQuickLaunch" => GhostField.new("OnQuickLaunch", "Bool", false, true),
        "Name" => GhostField.new("Name", "Text", false, true),
        "Sequence" => GhostField.new("Sequence", "Integer", false, true),
        "SecurityBits" => GhostField.new("SecurityBits", "Text", false, true),
        "Type" => GhostField.new("Type", "Integer", false, true),
        "UseRootFolderForNavigation" => GhostField.new("UseRootFolderForNavigation", "Bool", false, true),
        "VersioningEnabled" => GhostField.new("VersioningEnabled", "Bool", false, true)
      }
    end
    
  end
  
end
