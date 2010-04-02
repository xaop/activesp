module ActiveSP
  
  class Field < Base
    
    include InSite
    extend Caching
    include Util
    
    attr_reader :scope, :ID, :Name, :internal_type, :parent
    
    # There is no call to get to the field info directly, so these should always
    # be accessed through the site or list they belong to. Hence, we do not use
    # caching here as it is useless.
    def initialize(scope, id, name, type, parent, attributes_before_type_cast)
      @scope, @ID, @Name, @internal_type, @parent, @attributes_before_type_cast = scope, id, name, type, parent, attributes_before_type_cast
      @site = Site === @scope ? @scope : @scope.site
    end
    
    def key
      encode_key("A", [@scope.key, @ID])
    end
    
    def List
      list_for_lookup
    end
    
    def Type
      translate_internal_type(self)
    end
    
    # This is only defined when it is true; joy to the world!
    def Mult
      !!attributes["Mult"]
    end
    
    def ReadOnly
      !!attributes["ReadOnly"]
    end
    
    def to_s
      "#<ActiveSP::Field name=#{self.Name}>"
    end
    
    alias inspect to_s
    
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
    
    def internal_attribute_types
      @@internal_attribute_types ||= {
        "AllowDeletion" => GhostField.new("AllowDeletion", "Bool", false, true),
        "AppendOnly" => GhostField.new("AppendOnly", "Bool", false, true),
        "AuthoringInfo" => GhostField.new("AuthoringInfo", "Text", false, true),
        "CalType" => GhostField.new("CalType", "Integer", false, true),
        "CanToggleHidden" => GhostField.new("CanToggleHidden", "Bool", false, true),
        "ClassInfo" => GhostField.new("ClassInfo", "Text", false, true),
        "ColName" => GhostField.new("ColName", "Text", false, true),
        "Description" => GhostField.new("Description", "Text", false, true),
        "Dir" => GhostField.new("Dir", "Text", false, true),
        "DisplaceOnUpgrade" => GhostField.new("DisplaceOnUpgrade", "Bool", false, true),
        "DisplayImage" => GhostField.new("DisplayImage", "Text", false, true),
        "DisplayName" => GhostField.new("DisplayName", "Text", false, true),
        "DisplayNameSrcField" => GhostField.new("DisplayNameSrcField", "Text", false, true),
        "DisplaySize" => GhostField.new("DisplaySize", "Integer", false, true),
        "ExceptionImage" => GhostField.new("ExceptionImage", "Text", false, true),
        "FieldRef" => GhostField.new("FieldRef", "Text", false, true),
        "FillInChoice" => GhostField.new("FillInChoice", "Bool", false, true),
        "Filterable" => GhostField.new("Filterable", "Bool", false, true),
        "Format" => GhostField.new("Format", "Bool", false, true),
        "FromBaseType" => GhostField.new("FromBaseType", "Bool", false, true),
        "Group" => GhostField.new("Group", "Text", false, true),
        "HeaderImage" => GhostField.new("HeaderImage", "Text", false, true),
        "Height" => GhostField.new("Height", "Integer", false, true),
        "Hidden" => GhostField.new("Hidden", "Bool", false, true),
        "ID" => GhostField.new("ID", "Text", false, true),
        "IMEMode" => GhostField.new("IMEMode", "Text", false, true),
        "internal_type" => GhostField.new("internal_type", "Text", false, true),
        "IsolateStyles" => GhostField.new("IsolateStyles", "Bool", false, true),
        "JoinColName" => GhostField.new("JoinColName", "Text", false, true),
        "JoinRowOrdinal" => GhostField.new("JoinRowOrdinal", "Integer", false, true),
        "JoinType" => GhostField.new("JoinType", "Text", false, true),
        "List" => GhostField.new("List", "ListReference", false, true),
        "Max" => GhostField.new("Max", "Integer", false, true),
        "MaxLength" => GhostField.new("MaxLength", "Integer", false, true),
        "Min" => GhostField.new("Min", "Integer", false, true),
        "Mult" => GhostField.new("Mult", "Bool", false, true),
        "Name" => GhostField.new("Name", "Text", false, true),
        "Node" => GhostField.new("Node", "Text", false, true),
        "NoEditFormBreak" => GhostField.new("NoEditFormBreak", "Bool", false, true),
        "NumLines" => GhostField.new("NumLines", "Text", false, true),
        "Percentage" => GhostField.new("Percentage", "Bool", false, true),
        "PIAttribute" => GhostField.new("PIAttribute", "Text", false, true),
        "PITarget" => GhostField.new("PITarget", "Text", false, true),
        "PrependId" => GhostField.new("PrependId", "Bool", false, true),
        "PrimaryKey" => GhostField.new("PrimaryKey", "Bool", false, true),
        "PrimaryPIAttribute" => GhostField.new("PrimaryPIAttribute", "Text", false, true),
        "PrimaryPITarget" => GhostField.new("PrimaryPITarget", "Text", false, true),
        "ReadOnly" => GhostField.new("ReadOnly", "Bool", false, true),
        "ReadOnlyEnforced" => GhostField.new("ReadOnlyEnforced", "Bool", false, true),
        "RenderXMLUsingPattern" => GhostField.new("ReadOnly", "Bool", false, true),
        "Required" => GhostField.new("Required", "Bool", false, true),
        "RestrictedMode" => GhostField.new("RestrictedMode", "Bool", false, true),
        "RichText" => GhostField.new("RichText", "Bool", false, true),
        "RichTextMode" => GhostField.new("RichTextMode", "Text", false, true),
        "RowOrdinal" => GhostField.new("RowOrdinal", "Integer", false, true),
        "Sealed" => GhostField.new("Sealed", "Bool", false, true),
        "ShowInDisplayForm" => GhostField.new("ShowInDisplayForm", "Bool", false, true),
        "ShowInListSettings" => GhostField.new("ShowInListSettings", "Bool", false, true),
        "ShowInFileDlg" => GhostField.new("ShowInFileDlg", "Bool", false, true),
        "ShowInVersionHistory" => GhostField.new("ShowInVersionHistory", "Bool", false, true),
        "Sortable" => GhostField.new("Sortable", "Bool", false, true),
        "SourceID" => GhostField.new("SourceID", "Text", false, true),
        "StaticName" => GhostField.new("StaticName", "Text", false, true),
        "StorageTZ" => GhostField.new("StorageTZ", "Bool", false, true),
        "TextOnly" => GhostField.new("TextOnly", "Bool", false, true),
        "Title" => GhostField.new("Title", "Text", false, true),
        "Type" => GhostField.new("Type", "Text", false, true),
        "SetAs" => GhostField.new("SetAs", "Text", false, true),
        "ShowField" => GhostField.new("ShowField", "Text", false, true),
        "ShowInEditForm" => GhostField.new("ShowInEditForm", "Bool", false, true),
        "ShowInNewForm" => GhostField.new("ShowInNewForm", "Bool", false, true),
        "UnlimitedLengthInDocumentLibrary" => GhostField.new("UnlimitedLengthInDocumentLibrary", "Bool", false, true),
        "Version" => GhostField.new("Version", "Integer", false, true),
        "Width" => GhostField.new("Width", "Integer", false, true),
        "WikiLinking" => GhostField.new("WikiLinking", "Bool", false, true),
        "XName" => GhostField.new("XName", "Text", false, true)
      }
    end
    
  end
  
end
