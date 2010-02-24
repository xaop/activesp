module ActiveSP
  
  class Folder < Item
    
    def key
      encode_key("F", [parent.key, @id])
    end
    
    def items(options = {})
      @list.items(options.merge(:folder => self))
    end
    
    def item(name)
      query = Builder::XmlMarkup.new.Query do |xml|
        xml.Where do |xml|
          xml.Eq do |xml|
            xml.FieldRef(:Name => "FileLeafRef")
            xml.Value(name, :Type => "String")
          end
        end
      end
      items(:query => query).first
    end
    
    def /(name)
      item(name)
    end
    
    undef attachments
    undef content_urls
    
    def to_s
      "#<ActiveSP::Folder url=#{url}>"
    end
    
    alias inspect to_s
    
  end
  
end
