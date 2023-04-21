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
  class Field < Base
    include InSite
    extend Caching
    include Util
    extend Util

    # @private
    attr_reader :ID, :Name, :internal_type, :custom_props
    # Returns the scope of the field. This can be a site or a list
    # @return [Site, List]
    attr_reader :scope
    # Returns the parent field. This is the field defined on the containing site in case the field has a list as scope
    # @return [Field]
    attr_reader :parent

    # There is no call to get to the field info directly, so these should always
    # be accessed through the site or list they belong to. Hence, we do not use
    # caching here as it is useless.
    # @private
    def initialize(scope, id, name, type, parent, attributes_before_type_cast, custom_props = {})
      @scope, @ID, @Name, @internal_type, @parent, @attributes_before_type_cast, @custom_props = scope, id, name, type, parent, attributes_before_type_cast, custom_props
      @site = Site === @scope ? @scope : @scope.site
    end

    # See {Base#key}
    # @return [String]
    def key
      encode_key("A", [@scope.key, @ID])
    end

    # @private
    def List
      list_for_lookup
    end

    # @private
    def Type
      translate_internal_type(self)
    end

    # @private
    def Mult
      !!attributes["Mult"]
    end

    # @private
    def ReadOnly
      !!attributes["ReadOnly"]
    end

    # See {Base#save}
    # @return [void]
    def save
      p untype_cast_attributes(@site, nil, internal_attribute_types, changed_attributes, false)
    end

    # @private
    def to_s
      "#<ActiveSP::Field name=#{self.Name}>"
    end

    # @private
    alias inspect to_s

    def self.check_attributes_for_creation(site, attributes)
      name = attributes.delete("Name") or raise ArgumentError, "wrong type for Name attribute"
      name = name.to_s
      type = attributes.delete("internal_type") or raise ArgumentError, "wrong type for Name attribute"
      %[DateTime XMLDateTime Computed Text Guid ContentTypeId URL Integer Counter Attachments ModStat Number Bool File Note User InternalUser UserMulti Choice MultiChoice Lookup LookupMulti ThreadIndex].include?(type) or raise ArgumentError, "illegal value for internal_type attribute"
      attributes = type_check_attributes_for_creation(internal_attribute_types, attributes, false).merge("Name" => name, "Type" => type)
      untype_cast_attributes(site, nil, internal_attribute_types, attributes, false)
    end

  private

    def list_for_lookup
      # I think List may be undefined for attributes defined at the site level, and that they need to be specified
      # when used at the list level.
      if %w[Lookup LookupMulti].include?(@internal_type) and list = @attributes_before_type_cast["List"]
        if list[0] == ?{ && list[-1] == ?} # We have a GUID of a list
          ActiveSP::List.new(@site, list)
        elsif list == "Self"
          List === @scope ? @scope : nil
        end
      end
    end

    def original_attributes
      @original_attributes ||= type_cast_attributes(@site, nil, internal_attribute_types, @attributes_before_type_cast.merge("List" => list_for_lookup, "Type" => self.Type, "internal_type" => internal_type))
    end

    def self.internal_attribute_types
      @@internal_attribute_types ||= {
        "AllowDeletion" => GhostField.new("AllowDeletion", "Bool", false, true),
        "AppendOnly" => GhostField.new("AppendOnly", "Bool", false, true),
        "AuthoringInfo" => GhostField.new("AuthoringInfo", "Text", false, true),
        "CalType" => GhostField.new("CalType", "Integer", false, true),
        "CanToggleHidden" => GhostField.new("CanToggleHidden", "Bool", false, true),
        "ClassInfo" => GhostField.new("ClassInfo", "Text", false, true),
        "ColName" => GhostField.new("ColName", "Text", false, true),
        "Description" => GhostField.new("Description", "Text", false, false),
        "Dir" => GhostField.new("Dir", "Text", false, true),
        "DisplaceOnUpgrade" => GhostField.new("DisplaceOnUpgrade", "Bool", false, true),
        "DisplayImage" => GhostField.new("DisplayImage", "Text", false, true),
        "DisplayName" => GhostField.new("DisplayName", "Text", false, false),
        "DisplayNameSrcField" => GhostField.new("DisplayNameSrcField", "Text", false, true),
        "DisplaySize" => GhostField.new("DisplaySize", "Integer", false, true),
        "ExceptionImage" => GhostField.new("ExceptionImage", "Text", false, true),
        "FieldRef" => GhostField.new("FieldRef", "Text", false, true),
        "FillInChoice" => GhostField.new("FillInChoice", "Bool", false, true),
        "Filterable" => GhostField.new("Filterable", "Bool", false, false),
        "FilterableNoRecurrence" => GhostField.new("FilterableNoRecurrence", "Bool", false, false),
        "Format" => GhostField.new("Format", "Bool", false, false),
        "FromBaseType" => GhostField.new("FromBaseType", "Bool", false, false),
        "Group" => GhostField.new("Group", "Text", false, true),
        "HeaderImage" => GhostField.new("HeaderImage", "Text", false, true),
        "Height" => GhostField.new("Height", "Integer", false, true),
        "Hidden" => GhostField.new("Hidden", "Bool", false, false),
        "ID" => GhostField.new("ID", "Text", false, true),
        "IMEMode" => GhostField.new("IMEMode", "Text", false, true),
        "internal_type" => GhostField.new("internal_type", "Text", false, true),
        "IsolateStyles" => GhostField.new("IsolateStyles", "Bool", false, true),
        "JoinColName" => GhostField.new("JoinColName", "Text", false, true),
        "JoinRowOrdinal" => GhostField.new("JoinRowOrdinal", "Integer", false, true),
        "JoinType" => GhostField.new("JoinType", "Text", false, true),
        "List" => GhostField.new("List", "ListReference", false, false),
        "Max" => GhostField.new("Max", "Integer", false, true),
        "MaxLength" => GhostField.new("MaxLength", "Integer", false, true),
        "Min" => GhostField.new("Min", "Integer", false, true),
        "Mult" => GhostField.new("Mult", "Bool", false, true),
        "Name" => GhostField.new("Name", "Text", false, true),
        "Node" => GhostField.new("Node", "Text", false, false),
        "NoEditFormBreak" => GhostField.new("NoEditFormBreak", "Bool", false, true),
        "NumLines" => GhostField.new("NumLines", "Text", false, false),
        "Percentage" => GhostField.new("Percentage", "Bool", false, true),
        "PIAttribute" => GhostField.new("PIAttribute", "Text", false, true),
        "PITarget" => GhostField.new("PITarget", "Text", false, true),
        "PrependId" => GhostField.new("PrependId", "Bool", false, true),
        "PrimaryKey" => GhostField.new("PrimaryKey", "Bool", false, true),
        "PrimaryPIAttribute" => GhostField.new("PrimaryPIAttribute", "Text", false, true),
        "PrimaryPITarget" => GhostField.new("PrimaryPITarget", "Text", false, true),
        "ReadOnly" => GhostField.new("ReadOnly", "Bool", false, false),
        "ReadOnlyEnforced" => GhostField.new("ReadOnlyEnforced", "Bool", false, true),
        "RenderXMLUsingPattern" => GhostField.new("ReadOnly", "Bool", false, true),
        "Required" => GhostField.new("Required", "Bool", false, false),
        "RestrictedMode" => GhostField.new("RestrictedMode", "Bool", false, true),
        "RichText" => GhostField.new("RichText", "Bool", false, true),
        "RichTextMode" => GhostField.new("RichTextMode", "Text", false, true),
        "RowOrdinal" => GhostField.new("RowOrdinal", "Integer", false, true),
        "Sealed" => GhostField.new("Sealed", "Bool", false, false),
        "ShowInDisplayForm" => GhostField.new("ShowInDisplayForm", "Bool", false, false),
        "ShowInListSettings" => GhostField.new("ShowInListSettings", "Bool", false, false),
        "ShowInFileDlg" => GhostField.new("ShowInFileDlg", "Bool", false, false),
        "ShowInVersionHistory" => GhostField.new("ShowInVersionHistory", "Bool", false, true),
        "Sortable" => GhostField.new("Sortable", "Bool", false, false),
        "SourceID" => GhostField.new("SourceID", "Text", false, true),
        "StaticName" => GhostField.new("StaticName", "Text", false, true),
        "StorageTZ" => GhostField.new("StorageTZ", "Bool", false, true),
        "TextOnly" => GhostField.new("TextOnly", "Bool", false, true),
        "Title" => GhostField.new("Title", "Text", false, true),
        "Type" => GhostField.new("Type", "Text", false, true),
        "SetAs" => GhostField.new("SetAs", "Text", false, true),
        "ShowField" => GhostField.new("ShowField", "Text", false, false),
        "ShowInEditForm" => GhostField.new("ShowInEditForm", "Bool", false, false),
        "ShowInNewForm" => GhostField.new("ShowInNewForm", "Bool", false, false),
        "UnlimitedLengthInDocumentLibrary" => GhostField.new("UnlimitedLengthInDocumentLibrary", "Bool", false, true),
        "Version" => GhostField.new("Version", "Integer", false, true),
        "Width" => GhostField.new("Width", "Integer", false, true),
        "WikiLinking" => GhostField.new("WikiLinking", "Bool", false, true),
        "XName" => GhostField.new("XName", "Text", false, true)
      }
    end

    def internal_attribute_types
      self.class.internal_attribute_types
    end
  end
end

__END__

Reference of attributes for fields: http://msdn.microsoft.com/en-us/library/aa543225.aspx
