module ActiveSP
  class StsAuthenticator
    URL = "https://login.microsoftonline.com/GetUserRealm.srf"
    LIFE_TIME = 3600

    def self.getCookie(options = {})
      if @start && (Time.now > @start + LIFE_TIME)
        reset_cookie
      end
      @cookie ||= self.authenticate(options)
    end

    def self.reset_cookie
      @cookie = nil
    end

    def self.authenticate(options = {})
      @start = Time.now
      auth = self.new(options)
      auth.authenticate
      auth.cookie
    end

    attr_reader :cookie
    def initialize(options = {})
      @login = options[:login]
      @password = options[:password]
      @authentication_path = "#{options[:url].scheme}://#{options[:url].host}/_forms/default.aspx?wa=wsignin1.0"
      @sts_url = getStsUrl
      @cookie = false
    end

    def authenticate
      authenticate_to_sts
      get_security_token
      get_access_token
    end

    private

    def authenticate_to_sts
      guid = SecureRandom.uuid
      query    = Soap::Authenticate.new guid: guid, username: @login, password: @password, url: @sts_url
      begin
        response = Curl::Easy.http_post @sts_url, query.render do |c|
          c.ssl_verify_peer = false
          c.headers['Content-Type'] = 'application/soap+xml; charset=utf-8'
        end
      rescue Exception
        raise ConnexionToStsFailed.new
      end
      @assertion = response.body_str.scan(/<[^<]*Assertion.*><\/.*Assertion>/)[0].gsub("\"", "'")
    end

    def get_security_token
      query = Soap::GetToken.new security: @assertion
      response = Curl::Easy.http_post Soap::GetToken::URL, query.render do |c|
        c.ssl_verify_peer = false
        c.headers['Content-Type'] = 'application/soap+xml; charset=utf-8'
      end
      @security_token = response.body_str.scan(/BinarySecurityToken.*>([^<]+)</)[0][0]
    end

    def get_access_token
      http = Curl::Easy.http_post @authentication_path, @security_token
      @rtFa     = get_cookie_from_header http.header_str, 'rtFa'
      @fed_auth = get_cookie_from_header http.header_str, 'FedAuth'
      raise Exception.new if @fed_auth.nil? or @rtFa.nil?
      @cookie = "FedAuth=#{@fed_auth};rtFa=#{@rtFa}"
    end

    def get_cookie_from_header header, cookie_name
      result = nil
      header.scan(/#{cookie_name}=([^;]+);/) do
        offset = $~.offset 1
        result = header[offset[0]..offset[1] - 1]
      end
      result
    end
      
    def getStsUrl
      response = Curl::Easy.http_post URL, "login=#{@login.gsub("@", "%40")}&xml=1"
      return response.body_str.scan(/<STSAuthURL>([^<]+)</)[0][0]
    end
  end
end
