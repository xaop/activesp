require 'erb'

module ActiveSP
  module Soap
    class Authenticate
      SOURCE = "authenticate.xml.erb"

      attr_accessor :url, :guid, :username, :password, :login_url

      def self.initialize
        return if @initialized == true
        @erb          = ERB.new(::File.read ::File.dirname(__FILE__) + '/' + SOURCE)
        @erb.filename = SOURCE
        @erb.def_method self, 'render()'
        @initialized  = true
      end

      def initialize params = {}
        Authenticate.initialize
        now = Time.now.utc
        expire = now + (10 * 60)
        # expire = now + 1
        @guid  = params[:guid]
        @time1 = now.strftime("%Y-%m-%dT%H:%M:%S.%7NZ")
        @time2 = expire.strftime("%Y-%m-%dT%H:%M:%S.%7NZ")
        @username  = params[:username]
        @password  = params[:password]
        @login_url = params[:url]
      end
    end
  end
end
