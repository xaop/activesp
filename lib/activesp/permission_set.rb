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
  
  class PermissionSet
    
    include Util
    
    attr_reader :scope
    
    # @private
    def initialize(scope)
      @scope = scope
    end
    
    # See {Base#key}
    # @return [String]
    def key
      encode_key("P", [@scope.key])
    end
    
    # Returns the permissions in this permission set as an array of hashes with :accessor mapping to a user,
    # group or role and :mask mapping to the permission as an integer
    # @return [Array<Hash{:accessor, :permission => User, Group, Role, Integer}>]
    # @example
    #   set.permissions #=> [{:accessor=>#<ActiveSP::User login_name=SHAREPOINT\system>, :mask=>134287360}]
    def permissions
      @scope.send(:permissions)
    end
    
    # @private
    def to_s
      "#<ActiveSP::PermissionSet scope=#{@scope}>"
    end
    
    # @private
    alias inspect to_s
    
  end
  
end
