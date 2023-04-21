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

require 'nokogiri'
require 'time'
require 'curl'

module ActiveSP
end

require 'activesp/util'
require 'activesp/caching'
require 'activesp/associations'
require 'activesp/persistent_caching'

require 'activesp/errors'

require 'activesp/base'

require 'activesp/soap'
require 'activesp/sts_authenticator'
require 'activesp/connection'
require 'activesp/root'
require 'activesp/site'
require 'activesp/list'
require 'activesp/item'
require 'activesp/folder'
require 'activesp/url'
require 'activesp/content_type'
require 'activesp/field'
require 'activesp/ghost_field'
require 'activesp/user'
require 'activesp/group'
require 'activesp/user_group_proxy'
require 'activesp/role'
require 'activesp/permission_set'
require 'activesp/file'
require 'activesp/site_template'
require 'activesp/list_template'
