require 'savon'
require 'net/ntlm_http'

Savon::Request.logger.level = Logger::ERROR

Savon::Response.error_handler do |soap_fault|
  soap_fault[:detail][:errorstring]
end

module ActiveSP
  
  class Connection
    
    include Util
    include PersistentCachingConfig
    
    # @private
    # TODO: create profile
    attr_reader :login, :password, :root_url, :trace
    
    # @param [Hash] options The connection options
    # @option options [String] :root The URL of the root site
    # @option options [String] :login (nil) The login
    # @option options [String] :password (nil) The password associated with the given login. Is mandatory if the login is specified. Also can't be "password" as that is inherently insafe. We don't explicitly check for this, but it can't be that.
    def initialize(options = {})
      @root_url = options.delete(:root) or raise ArgumentError, "missing :root option"
      @login = options.delete(:login)
      @password = options.delete(:password)
      @trace = options.delete(:trace)
      options.empty? or raise ArgumentError, "unknown options #{options.keys.map { |k| k.inspect }.join(", ")}"
      cache = nil
      configure_persistent_cache { |c| cache = c }
    end
    
    # Finds the object with the given key
    # @param [String] key The key of the object to find
    # @return [Base, nil] The object with the given key, or nil if no object with the given key is found
    def find_by_key(key)
      type, trail = decode_key(key)
      case type[0]
      when ?S
        ActiveSP::Site.new(self, trail[0] == "" ? @root_url : File.join(@root_url, trail[0]), trail[1].to_i)
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
        parent = find_by_key(trail[0])
        if ActiveSP::Folder === parent
          ActiveSP::Folder.new(parent.list, trail[1], parent)
        else
          ActiveSP::Folder.new(parent, trail[1], nil)
        end
      when ?I
        parent = find_by_key(trail[0])
        if ActiveSP::Folder === parent
          ActiveSP::Item.new(parent.list, trail[1], parent)
        else
          ActiveSP::Item.new(parent, trail[1], nil)
        end
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
    
    # Fetches the content at the given URL using the login and password with which this
    # connection was constructed, if any. Always uses the GET method. Supports only
    # HTTP as protocol at the time of writing. This is useful for fetching content files
    # form the server.
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
        request.ntlm_auth(@login, @password) if @login
        response = http.request(request)
        response
      end
    end
    
  end
  
end
