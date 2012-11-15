module Savon
  module Wasabi
    class Document
      def authenticate(options)
        @request ||= HTTPI::Request.new
        case options[:method]
        when :ntlm
          @request.auth.ntlm(options[:usename], options[:password])
        when :basic
          @request.auth.basic(options[:usename], options[:password])
        when :digest
          @request.auth.digest(options[:usename], options[:password])
        when :gss_negotiate
          @request.auth.gssnegotiate(options[:usename], options[:password])
        end
      end
    end
  end
end
