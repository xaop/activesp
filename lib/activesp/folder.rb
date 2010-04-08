module ActiveSP
  
  class Folder < Item
    
    # See {Base#key}
    # @return [String]
    def key
      encode_key("F", [parent.key, @id])
    end
    
    # Returns the list of items in this folder
    # @param [Hash] options See {List#items}, :folder option has no effect
    # @return [Array<Item>]
    def items(options = {})
      @list.items(options.merge(:folder => self))
    end
    
    # Returns the item with the given name
    # @param [String] name
    # @return [Item]
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
    
    alias / item
    
    undef attachments
    undef content_urls
    
    # @private
    def to_s
      "#<ActiveSP::Folder url=#{url}>"
    end
    
    # @private
    alias inspect to_s
    
  end
  
end
