module ActiveSP
  
  module Root
    
    include Caching
    
    def root
      Site.new(self, @root_url)
    end
    cache :root
    
    def users
      root.send(:call, "UserGroup", "get_user_collection_from_site").xpath("//spdir:User", NS).map do |row|
        attributes = row.attributes.inject({}) { |h, (k, v)| h[k] = v.to_s ; h }
        User.new(root, attributes["LoginName"])
      end
    end
    cache :users
    
    def groups
      root.send(:call, "UserGroup", "get_group_collection_from_site").xpath("//spdir:Group", NS).map do |row|
        attributes = row.attributes.inject({}) { |h, (k, v)| h[k] = v.to_s ; h }
        Group.new(root, attributes["Name"])
      end
    end
    cache :groups
    
    def roles
      root.send(:call, "UserGroup", "get_role_collection_from_web").xpath("//spdir:Role", NS).map do |row|
        attributes = row.attributes.inject({}) { |h, (k, v)| h[k] = v.to_s ; h }
        Role.new(root, attributes["Name"])
      end
    end
    cache :roles
    
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
