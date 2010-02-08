module ActiveSP
  
  module Util
    
  private
    
    def clean_list_attributes(attributes)
      attributes.inject({}) { |h, (k, v)| h[k] = v.to_s ; h }
    end
    
    def clean_item_attributes(fields, attributes)
      attributes.inject({}) do |h, (k, v)|
        k = k.sub(/\Aows_/, "")
        field = fields[k] or raise ArgumentError, "can't find field #{k.inspect}"
        v = v.to_s
        case field.type
        when "Lookup"
          v = v.sub(/\A.*?;#/, "")
        when "DateTime"
          Time.parse(v)
        when "Computed"
        when "User"
          v = v.sub(/\A.*?;#/, "")
        when "Text", "Guid", "ContentTypeId"
        when "Integer", "Counter"
          v = v.to_i
        when "ModStat" # 0
        when "Number"
          v = v.to_f
        when "Boolean"
          v = v == "1"
        when "File"
          v = v.sub(/\A.*?;#/, "")
        when "Choice"
        when "Note"
        when "Attachments"
        when "LookupMulti"
          # raise [k, v].inspect
        else
          raise NotImplementedError, "don't know type #{field.type.inspect} for #{k}=#{v.inspect}"
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
    
  end
  
end
