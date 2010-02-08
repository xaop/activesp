module ActiveSP
  
  module Root
    
    include Caching
    
    def root
      Site.new(self, @root_url)
    end
    cache :root
    
  end
  
  class Connection
    
    include Root
    
  end
  
  module InSite
    
  private
    
    def call(*a, &b)
      @site.send(:call, *a, &b)
    end
    
    def fetch(url)
      @site.send(:fetch, url)
    end
    
  end
  
end
