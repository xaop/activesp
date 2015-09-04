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
  NS = {
    "sp" => "http://schemas.microsoft.com/sharepoint/soap/",
    "SP" => "http://schemas.microsoft.com/sharepoint/",
    "z" => "#RowsetSchema",
    "spdir" => "http://schemas.microsoft.com/sharepoint/soap/directory/",
    "meet" => "http://schemas.microsoft.com/sharepoint/soap/meetings/"
  }
  
  module Root
    
    extend Caching
    
    # Returns the root site as an object of class {Site}
    # @return [Site]
    def root
      Site.new(self, @root_url)
    end
    cache :root
    
    # Returns the list of users in the system
    # @return [Array<User>]
    def users
      root.send(:call, "UserGroup", "GetUserCollectionFromSite").xpath("//spdir:User", NS).map do |row|
        attributes = clean_attributes(row.attributes)
        User.new(root, attributes["LoginName"], attributes)
      end
    end
    cache :users, :dup => :always
    
    # Returns the user with the given login, or nil when the user does not exist
    # @param [String] login The login of the user
    # @return [User, nil]
    def user(login)
      if user = users_by_login[login]
        user
      elsif data = root.send(:call, "UserGroup", "get_user_info", "userLoginName" => login).xpath("//spdir:User", NS).first
        users_by_login[login] = User.new(root, login, clean_attributes(data))
      end
    end
    
    # Returns the list of groups in the system
    # @return [Array<Group>]
    def groups
      root.send(:call, "UserGroup", "get_group_collection_from_site").xpath("//spdir:Group", NS).map do |row|
        attributes = clean_attributes(row.attributes)
        Group.new(root, attributes["Name"])
      end
    end
    cache :groups, :dup => :always
    
    def group(name)
      if group = groups_by_name[name]
        group
      end
    end
    
    # Returns the list of roles in the system
    # @return [Array<Role>]
    def roles
      root.send(:call, "UserGroup", "get_role_collection_from_web").xpath("//spdir:Role", NS).map do |row|
        attributes = clean_attributes(row.attributes)
        Role.new(root, attributes["Name"])
      end
    end
    cache :roles, :dup => :always
    
    def site_templates
      root.send(:call, "Sites", "GetSiteTemplates", "LCID" => 1033).xpath("//sp:Template", NS).map do |row|
        attributes = clean_attributes(row.attributes)
        ActiveSP::SiteTemplate.new(root, attributes["Name"], attributes)
      end
    end
    cache :site_templates, :dup => :always
    
    def site_template(name)
      site_templates.find { |template| template.Name == name }
    end
    
    def list_templates
      result = root.send(:call, "Webs", "GetListTemplates")
      result.xpath("//SP:ListTemplate", NS).map do |row|
        attributes = clean_attributes(row.attributes)
        ActiveSP::ListTemplate.new(root, attributes["Type"].to_i, attributes)
      end
    end
    
    def list_template(type)
      list_templates.find { |template| template.Type == type }
    end
    
  private
    
    def users_by_login
      users.inject({}) { |h, u| h[u.login_name] = u ; h }
    end
    cache :users_by_login
    
    def groups_by_name
      groups.inject({}) { |h, g| h[g.Name] = g ; h }
    end
    cache :groups_by_name
    
  end
  
  class Connection
    
    include Root
    
  end
  
  # @private
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
