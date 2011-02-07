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
  
  class Folder < Item
    
    # See {Base#key}
    # @return [String]
    def key
      encode_key("F", [@list.key, @id])
    end
    
    def is_folder?
      true
    end
    
    # Returns the list of items in this folder
    # @param [Hash] options See {List#each_item}, :folder option has no effect
    # @return [Array<Item>]
    def each_item(options = {}, &blk)
      @list.each_item(options.merge(:folder => self), &blk)
    end
    association :items
    
    def each_folder(options = {}, &blk)
      @list.each_folder(options.merge(:folder => self), &blk)
    end
    association :folders do
      def create(parameters = {})
        @object.create_folder(parameters)
      end
    end
    
    def create_folder(parameters = {})
      @list.create_folder(parameters.merge(:folder => absolute_url))
    end
    
    def each_document(options = {}, &blk)
      @list.each_document(options.merge(:folder => self), &blk)
    end
    association :documents do
      def create(parameters = {})
        @object.create_document(parameters)
      end
    end
    
    def create_document(parameters = {})
      @list.create_document(parameters.merge(:folder => absolute_url, :folder_object => self))
    end
    
    # Returns the item with the given name
    # @param [String] name
    # @return [Item]
    def item(name)
      query = Builder::XmlMarkup.new.Query do |xml|
        xml.Where do |xml|
          xml.Eq do |xml|
            xml.FieldRef(:Name => "FileLeafRef")
            xml.Value(name, :Type => "Text")
          end
        end
      end
      items(:query => query).first
    end
    
    alias / item
    
    undef content
    
    # @private
    def to_s
      "#<ActiveSP::Folder url=#{url}>"
    end
    
    # @private
    alias inspect to_s
    
  end
  
end
