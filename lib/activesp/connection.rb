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

Savon::Request.logger.level = Logger::ERROR

Savon::Response.error_handler do |soap_fault|
  soap_fault[:detail][:errorstring]
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
      else
        raise "not yet #{key.inspect}"
      end
    end
    
    def with_sts_auth_retry(nbr = 1)
      @sts_retry ||= 0
      begin
        r = yield false 
        @sts_retry = 0
        r
      rescue Savon::HTTP::Error => e
        if (auth_type == :sts) && (@sts_retry < nbr) && (e.to_hash[:code] == 403) # FORBIDDEN
          StsAuthenticator.reset_cookie
          @sts_retry += 1
          yield true
        else
          raise e
        end
      end
    end
    
    def authenticate(http)
      if login
        case auth_type
        when :ntlm
          http.ntlm_auth(login, password)
        when :basic
          http.basic_auth(login, password)
        when :sts
          http.headers["Cookie"] = StsAuthenticator.getCookie(:login => login, :password => password, :url => URI.parse(@root_url))
        else
          raise ArgumentError, "Unknown authentication type #{auth_type.inspect}"
        end
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
      Net::HTTP.start(*@open_params) do |http|
        request = Net::HTTP::Get.new(URL(url).full_path.gsub(/ /, "%20"))
        with_sts_auth_retry do
          authenticate(request)
          HTTPI.get(request)
          http.request(request)
        end
      end
    end
    
    def head(url)
      # TODO: support HTTPS too
      @open_params ||= begin
        u = URL(@root_url)
        [u.host, u.port]
      end
      Net::HTTP.start(*@open_params) do |http|
        request = Net::HTTP::Head.new(URL(url).full_path.gsub(/ /, "%20"))
        if @login
          case auth_type
          when :ntlm
            request.ntlm_auth(@login, @password)
          when :basic
            request.basic_auth(@login, @password)
          else
            raise ArgumentError, "Unknown authentication type #{auth_type.inspect}"
          end
        end
        response = http.request(request)
        # if Net::HTTPFound === response
        #   response = fetch(response["location"])
        # end
        # response
      end
    end
    
  end
  
end
