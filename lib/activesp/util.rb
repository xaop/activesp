module ActiveSP
  
  module Util
    
  private
    
    def clean_list_attributes(attributes)
      attributes.inject({}) { |h, (k, v)| h[k] = v.to_s ; h }
    end
    
    def clean_item_attributes(attributes)
      attributes.inject({}) { |h, (k, v)| h[k.sub(/\Aows_/, "")] = v.to_s ; h }
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
