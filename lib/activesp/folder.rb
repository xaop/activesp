module ActiveSP
  
  class Folder < Item
    
    def key
      encode_key("F", [parent.key, @id])
    end
    
    def items
      @list.items(:folder => self)
    end
    
    undef attachments
    undef content_urls
    
    def to_s
      "#<ActiveSP::Folder url=#{url}>"
    end
    
    alias inspect to_s
    
  end
  
end
