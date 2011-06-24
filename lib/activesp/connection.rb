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

require 'savon'
require 'net/ntlm_http'

Savon.configure do |config|
  config.log = false
end

HTTPI.log = false

HTTPI.adapter = :curb

class Savon::SOAP::Fault
  
  def error_code
    Integer(((to_hash[:fault] || {})[:detail] || {})[:errorcode] || 0)
  end
  
  def error_string
    ((to_hash[:fault] || {})[:detail] || {})[:errorstring]
  end
  
end

class HTTPI::Auth::Config
  
  # Accessor for the GSSNEGOTIATE auth credentials.
  def gssnegotiate(*args)
    return @gssnegotiate if args.empty?
    
    self.type = :gssnegotiate
    @gssnegotiate = args.flatten.compact
  end
  
  # Returns whether to use GSSNEGOTIATE auth.
  def gssnegotiate?
    type == :gssnegotiate
  end
  
end

class HTTPI::Adapter::Curb
  
  def setup_client(request)
    basic_setup request
    setup_http_auth request if request.auth.http?
    setup_ssl_auth request.auth.ssl if request.auth.ssl?
    setup_ntlm_auth request if request.auth.ntlm?
    setup_gssnegotiate_auth request if request.auth.gssnegotiate?
  end
  
  def setup_gssnegotiate_auth(request)
    client.username, client.password = *request.auth.credentials
    client.http_auth_types = request.auth.type
  end
  
end

# This is because setting the cookie causes problems on SP 2011
class Savon::Client
  
private
  
  def set_cookie(headers)
  end
  
end

module ActiveSP
  
  # This class is uses to configure the connection to a SharePoint repository. This is
  # the starting point for doing anything with SharePoint.
  class Connection
    
    include Util
    include PersistentCachingConfig
    
    # @private
    # TODO: create profile
    attr_reader :login, :password, :auth_type, :root_url, :trace
    
    # @param [Hash] options The connection options
    # @option options [String] :root The URL of the root site
    # @option options [String] :auth_type (:ntlm) The authentication type, can be :basic or :ntlm.
    # @option options [String] :login (nil) The login
    # @option options [String] :password (nil) The password associated with the given login. Is mandatory if the login is specified. Also can't be "password" as that is inherently insafe. We don't explicitly check for this, but it can't be that.
    def initialize(options = {})
      options = options.dup
      @root_url = options.delete(:root) or raise ArgumentError, "missing :root option"
      @login = options.delete(:login)
      @password = options.delete(:password)
      @auth_type = options.delete(:auth_type) || :ntlm
      @trace = options.delete(:trace)
      options.empty? or raise ArgumentError, "unknown options #{options.keys.map { |k| k.inspect }.join(", ")}"
      cache = nil
      configure_persistent_cache { |c| cache ||= c }
    end
    
    # Finds the object with the given key
    # @param [String] key The key of the object to find
    # @return [Base, nil] The object with the given key, or nil if no object with the given key is found
    def find_by_key(key)
      type, trail = decode_key(key)
      case type[0]
      when ?S
        ActiveSP::Site.new(self, trail[0] == "" ? @root_url : ::File.join(@root_url, trail[0]), trail[1].to_i)
      when ?L
        ActiveSP::List.new(find_by_key(trail[0]), trail[1])
      when ?U
        ActiveSP::User.new(root, trail[0])
      when ?G
        ActiveSP::Group.new(root, trail[0])
      when ?R
        ActiveSP::Role.new(root, trail[0])
      when ?A
        find_by_key(trail[0]).field(trail[1])
      when ?P
        ActiveSP::PermissionSet.new(find_by_key(trail[0]))
      when ?F
        list = find_by_key(trail[0])
        ActiveSP::Folder.new(list, trail[1])
      when ?I
        list = find_by_key(trail[0])
        ActiveSP::Item.new(list, trail[1])
      when ?T
        parent = find_by_key(trail[0])
        if ActiveSP::List === parent
          ActiveSP::ContentType.new(parent.site, parent, trail[1])
        else
          ActiveSP::ContentType.new(parent, nil, trail[1])
        end
      when ?M
        case type[1]
        when ?S
          site_template(trail[0])
        when ?L
          list_template(trail[0].to_i)
        else
          raise "not yet #{key.inspect}"
        end
      else
        raise "not yet #{key.inspect}"
      end
    end
    
    # Fetches the content at the given URL using the login and password with which this
    # connection was constructed, if any. Always uses the GET method. Supports only
    # HTTP as protocol at the time of writing. This is useful for fetching content files
    # from the server.
    # @param [String] url The URL to fetch
    # @return [String] The content fetched from the URL
    def fetch(url)
      # TODO: support HTTPS too
      @open_params ||= begin
        u = URL(@root_url)
        [u.host, u.port]
      end
      # Net::HTTP.start(*@open_params) do |http|
      #   request = Net::HTTP::Get.new(URL(url).full_path.gsub(/ /, "%20"))
      #   if @login
      #     case auth_type
      #     when :ntlm
      #       request.ntlm_auth(@login, @password)
      #     when :basic
      #       request.basic_auth(@login, @password)
      #     else
      #       raise ArgumentError, "Unknown authentication type #{auth_type.inspect}"
      #     end
      #   end
      #   response = http.request(request)
      #   # if Net::HTTPFound === response
      #   #   response = fetch(response["location"])
      #   # end
      #   # response
      # end
      request = HTTPI::Request.new("http://#{@open_params.join(':')}#{url.gsub(/ /, "%20")}")
      if login
        case auth_type
        when :ntlm
          request.auth.ntlm(login, password)
        when :basic
          request.auth.basic(login, password)
        when :digest
          request.auth.digest(login, password)
        when :gss_negotiate
          request.auth.gssnegotiate(login, password)
        else
          raise ArgumentError, "Unknown authentication type #{auth_type.inspect}"
        end
      end
      HTTPI.get(request)
    end
    
    def head(url)
      # TODO: support HTTPS too
      @open_params ||= begin
        u = URL(@root_url)
        [u.host, u.port]
      end
      # Net::HTTP.start(*@open_params) do |http|
      #   request = Net::HTTP::Head.new(URL(url).full_path.gsub(/ /, "%20"))
      #   if @login
      #     case auth_type
      #     when :ntlm
      #       request.ntlm_auth(@login, @password)
      #     when :basic
      #       request.basic_auth(@login, @password)
      #     else
      #       raise ArgumentError, "Unknown authentication type #{auth_type.inspect}"
      #     end
      #   end
      #   response = http.request(request)
      #   # if Net::HTTPFound === response
      #   #   response = fetch(response["location"])
      #   # end
      #   # response
      # end
      request = HTTPI::Request.new("http://#{@open_params.join(':')}#{url.gsub(/ /, "%20")}")
      if login
        case auth_type
        when :ntlm
          request.auth.ntlm(login, password)
        when :basic
          request.auth.basic(login, password)
        when :digest
          request.auth.digest(login, password)
        when :gss_negotiate
          request.auth.gssnegotiate(login, password)
        else
          raise ArgumentError, "Unknown authentication type #{auth_type.inspect}"
        end
      end
      HTTPI.head(request).headers
    end
    
  end
  
end
