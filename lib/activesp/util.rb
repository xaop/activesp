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
  
  # @private
  module Util
    
  private
    
    def decode_field_name(name)
      name.gsub(/_x([0-9af]{4})_/i) { [$1.to_i(16)].pack("U") }
    end
    
    def clean_attributes(attributes)
      attributes.inject({}) { |h, (k, v)| h[k] = v.to_s ; h }
    end
    
    def clean_item_attributes(attributes)
      attributes.inject({}) { |h, (k, v)| h[k.sub(/\Aows_/, "")] = v.to_s ; h }
    end
    
    def type_cast_attributes(site, list, fields, attributes)
      result = attributes.inject({}) do |h, (k, v)|
        k = decode_field_name(k)
        if field = fields[k]
          case field.internal_type
          when "ListReference"
          when "StandardDateTime"
            v = Time.parse(v)
          when "DateTime"
            v = Time.parse(v)
          when "XMLDateTime"
            v = Time.xmlschema(v.sub(/ /, "T"))
          when "Computed", "Text", "Guid", "ContentTypeId", "URL"
          when "Integer", "Counter", "Attachments"
            v = v && v != "" ? Integer(v) : nil
          when "ModStat" # 0
          when "Number"
            v = v.to_f
          when "Boolean"
            v = v == "1"
          when "Bool"
            v = !!v[/true/i]
          when "File"
            # v = v.sub(/\A.*?;#/, "")
          when "Note"
          
          when "User"
            d = split_multi(v)
            v = create_user_or_group(site, d[2])
          when "InternalUser"
            v = create_user_or_group(site, v)
          when "UserMulti"
            d = split_multi(v)
            v = (0...(d.length / 4)).map { |i| create_user_or_group(site, d[4 * i + 2]) }
          
          when "Choice"
            # For some reason there is no encoding here
          when "MultiChoice"
            # SharePoint disallows ;# inside choices and starts with a ;#
            v = v.split(/;#/)[1..-1]
          
          when "Lookup"
            d = split_multi(v)
            if field.List
              v = construct_item_from_id(field.List, d[0])
            else
              v = d[2]
            end
          when "LookupMulti"
            d = split_multi(v)
            if field.List
              v = (0...(d.length / 4)).map { |i| construct_item_from_id(field.List, d[4 * i]) }
            else
              v = (0...(d.length / 4)).map { |i| d[4 * i + 2] }
            end
          
          else
            # raise NotImplementedError, "don't know type #{field.type.inspect} for #{k}=#{v.inspect}"
            # Note: can't print self if it needs the attributes to be loaded, so just display the class
            # warn "don't know type #{field.internal_type.inspect} for #{k}=#{v.inspect} on #{self.class}"
          end
        else
          # raise ArgumentError, "can't find field #{k.inspect}"
          # Note: can't print self if it needs the attributes to be loaded, so just display the class
          # warn "can't find field #{k.inspect} on #{self.class}"
        end
        h[k] = v
        h
      end
      fields.each_key do |k|
        result[k] = nil unless result.has_key?(k)
      end
      result
    end
    
    def create_user_or_group(site, entry)
      if entry == "System Account"
        User.new(site.connection.root, "SHAREPOINT\\system")
      elsif entry[/\\/]
        User.new(site.connection.root, entry)
      else
        Group.new(site.connection.root, entry)
      end
    end
    
    def type_check_attribute(field, value)
      case field.internal_type
      when "Text", "File"
        value.to_s
      when "Bool", "Boolean"
        !!value
      when "Integer"
        Integer(value)
      when "StandardDateTime", "XMLDateTime"
        Time === value and value or raise ArgumentError, "wrong type for #{field.Name} attribute"
      when "InternalUser"
        value = value.to_s
        @site.rootsite.user(value) and value or raise ArgumentError, "user with login #{value} does not exist for #{field.Name} attribute"
      when "Lookup"
        if field.List
          if ::ActiveSP::Item === value && value.list == field.List
            value
          else
            raise ArgumentError, "wrong type for #{field.Name} attribute"
          end
        else
          value.to_s
        end
      when "LookupMulti"
        if field.List
          begin
            value = Array(value)
          rescue Exception
            raise ArgumentError, "wrong type for #{field.Name} attribute"
          end
          value.map do |val|
            if ::ActiveSP::Item === val && val.list == field.List
              val
            else
              raise ArgumentError, "wrong type for #{field.Name} attribute"
            end
          end
        else
          raise ArgumentError, "wrong type for #{field.Name} attribute"
        end
      when "DateTime"
        Time === value and value or raise ArgumentError, "wrong type for #{field.Name} attribute"
      when "User"
        if ::ActiveSP::User === value || field.attributes["UserSelectionMode"] == "PeopleAndGroups" && ::ActiveSP::Group === value
          # TODO: check if the user is in the correct group in case a group is specified
          value
        else
          raise ArgumentError, "wrong type for #{field.Name} attribute"
        end
      when "UserMulti"
        begin
          value = Array(value)
        rescue Exception
          raise ArgumentError, "wrong type for #{field.Name} attribute"
        end
        value.map do |val|
          if ::ActiveSP::User === val || field.attributes["UserSelectionMode"] == "PeopleAndGroups" && ::ActiveSP::Group === val
            # TODO: check if the user is in the correct group in case a group is specified
            val
          else
            raise ArgumentError, "wrong type for #{field.Name} attribute"
          end
        end
      else
        raise "not yet #{field.Name}:#{field.internal_type}"
      end
    end
    
    def type_check_attributes_for_creation(fields, attributes)
      attributes.inject({}) do |h, (k, v)|
        if field = fields[k]
          if !field.ReadOnly
            h[k] = type_check_attribute(field, v)
            h
          else
            raise ArgumentError, "field #{field.Name} is read-only"
          end
        else
          raise "can't find field #{k.inspect}"
        end
      end
    end
    
    def untype_cast_attributes(site, list, fields, attributes)
      attributes.inject({}) do |h, (k, v)|
        if field = fields[k]
          case field.internal_type
          when "Text", "File"
          when "Bool"
            v = v ? "TRUE" : "FALSE"
          when "Boolean"
            v = v ? "1" : "0"
          when "Integer"
            v = v.to_s
          when "DateTime"
            v = v.strftime("%Y-%m-%d %H:%M:%S")
          when "User"
            v = v.ID
          when "UserMulti"
            v = v.map { |ug| ug.ID }.join(";#;#")
          when "Lookup"
            v = v.ID
          when "LookupMulti"
            v = v.map { |i| i.ID }.join(";#;#")
          else
            raise "don't know type #{field.internal_type.inspect} for #{k}=#{v.inspect} on self"
          end
        else
          raise "can't find field #{k.inspect} on #{self}"
        end
        h[k] = v
        h
      end
    end
    
    def construct_xml_for_copy_into_items(fields, attributes)
      attributes.map do |k, v|
        field = fields[k]
        Builder::XmlMarkup.new.wsdl(
          :FieldInformation,
          "Type" => field.internal_type,
          "Id" => field.ID,
          "Value" => v,
          "InternalName" => field.StaticName,
          "DisplayName" => field.DisplayName
        )
      end.join("")
    end
    
    def construct_xml_for_update_list_items(xml, fields, attributes)
      attributes.map do |k, v|
        field = fields[k]
        xml.Field(v, "Name" => field.StaticName)
      end
    end
    
    def encode_key(type, trail)
      "#{type}::#{trail.map { |t| t.to_s.gsub(/:/, ":-") }.join("::")}"
    end
    
    def decode_key(key)
      type, *trail = key.split(/::/)
      [type, trail.map { |t| t.gsub(/:-/, ':') }]
    end
    
    def split_multi(s)
      # Figure out the exact escaping rules that SharePoint uses
      s.scan(/((?:[^;]|;;#|;[^#;]|;;(?!#))+)(;#)?/).flatten
    end
    
    def construct_item_from_id(list, id)
      query = Builder::XmlMarkup.new.Query do |xml|
        xml.Where do |xml|
          xml.Eq do |xml|
            xml.FieldRef(:Name => "ID")
            xml.Value(id, :Type => "Counter")
          end
        end
      end
      list.items(:query => query).first
    end
    
    def translate_internal_type(field)
      case field.internal_type
      when "Computed", "Text", "Guid", "ContentTypeId", "URL", "Choice", "MultiChoice", "File", "Note"
        "Text"
      when "Integer", "Counter", "Attachments", "ModStat"
        "Integer"
      when "Number"
        "Float"
      when "StandardDateTime", "DateTime", "XMLDateTime"
        "DateTime"
      when "Boolean", "Bool"
        "Boolean"
      when "User", "InternalUser", "UserMulti"
        "UserReference"
      when "Lookup", "LookupMulti"
        if field.List
          "ItemReference"
        else
          "Text"
        end
      when "ListReference"
        "ListReference"
      else
        "Text"
      end
    end
    
    # Somewhat dirty
    def escape_xml(xml)
      Builder::XmlMarkup.new.s(xml).scan(/\A<s>(.*)<\/s>\z/)
    end
    
  end
  
end
