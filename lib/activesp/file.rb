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
  
  class File
    
    include InSite
    
    attr_reader :url
    
    def initialize(item, url, destroyable)
      @item, @url, @destroyable = item, url, destroyable
      @site = @item.list.site
    end
    
    def file_name
      ::File.basename(@url)
    end
    
    def data
      @item.list.site.connection.fetch(@url).body
    end
    
    def content_type
      head_data["content-type"]
    end
    
    def content_size
      head_data["content-length"].to_i
    end
    
    def destroy
      if @destroyable
        result = call("Lists", "delete_attachment", "listName" => @item.list.id, "listItemID" => @item.ID, "url" => @url)
        if delete_result = result.xpath("//sp:DeleteAttachmentResponse", NS).first
          @item.clear_cache_for(:attachment_urls)
          self
        else
          raise "file could not be deleted"
        end
      else
        raise TypeError, "this file cannot be destroyed"
      end
    end
    
    # @private
    def to_s
      "#<ActiveSP::File url=#{@url}>"
    end
    
    # @private
    alias inspect to_s
    
  private
    
    def head_data
      @head_data ||= @item.list.site.connection.head(@url)
    end
    
  end
  
end

