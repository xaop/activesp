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
    
    def clean_attributes(attributes)
      attributes.inject({}) { |h, (k, v)| h[k] = v.to_s ; h }
    end
    
    def clean_item_attributes(attributes)
      attributes.inject({}) { |h, (k, v)| h[k.sub(/\Aows_/, "")] = v.to_s ; h }
    end
    
    def type_cast_attributes(site, list, fields, attributes)
      attributes.inject({}) do |h, (k, v)|
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
            v = User.new(site.connection.root, d[2][/\\/] ? d[2] : "SHAREPOINT\\system")
          when "InternalUser"
            v = User.new(site.connection.root, v[/\\/] ? v : "SHAREPOINT\\system")
          when "UserMulti"
            d = split_multi(v)
            v = (0...(d.length / 4)).map { |i| User.new(site.connection.root, d[4 * i + 2][/\\/] ? d[4 * i + 2] : "SHAREPOINT\\system") }
          
          when "Choice"
            # For some reason there is no encoding here
          when "MultiChoice"
            # SharePoint disallows ;# inside choices and starts with a ;#
            v = v.split(/;#/)[1..-1]
          
          when "Lookup"
            d = split_multi(v)
            if field.List
              v = create_item_from_id(field.List, d[0])
            else
              v = d[2]
            end
          when "LookupMulti"
            d = split_multi(v)
            if field.List
              v = (0...(d.length / 4)).map { |i| create_item_from_id(field.List, d[4 * i]) }
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
    end
    
    def type_check_attribute(field, value)
      case field.internal_type
      when "Text"
        value.to_s
      when "Bool"
        !!value
      when "Integer"
        Integer(value)
      when "StandardDateTime", "XMLDateTime"
        Time === value and value or raise ArgumentError, "wrong type for #{field.Name} attribute"
      when "InternalUser"
        value = value.to_s
        @site.rootsite.user(value) and value or raise ArgumentError, "user with login #{value} does not exist for #{field.Name} attribute"
      else
        raise "not yet #{field.inspect}"
      end
    end
    
    def untype_cast_attributes(site, list, fields, attributes)
      attributes.inject({}) do |h, (k, v)|
        if field = fields[k]
          case field.internal_type
          when "Text"
          when "Bool"
            v = v ? "TRUE" : "FALSE"
          when "Integer"
            v = v.to_s
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
    
    def create_item_from_id(list, id)
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
    
  end
  
end


__END__

escaping in field names:

_x[4-digit code]_

[space]      20
<            3C
>            3E
#            23
%            25
{            7B
}            7D
|            7C
\            5C
^            5E
~            7E
[            5B
]            5D
`            60
;            3B
/            2F
?            3F
:            3A
@            40
=            3D
&            26
$            24
