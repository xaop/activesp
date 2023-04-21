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

# @private
def URL(*args)
  case args.length
  when 1
    url = args[0]
    if URL === url
      url
    else
      URL.parse(url)
    end
  when 2..6
    URL.new(*args)
  else
    raise ArgumentError, "wrong number of arguments (#{args.length} for 1..6)"
  end
end

# @private
class URL < Struct.new(:protocol, :host, :port, :path, :query, :fragment)
  def self.parse(url)
    if /^(?:([^:\/?#]+):)?(?:\/\/([^\/?#:]*)(?::(\d+))?)?([^?#]*)(?:\?([^#]*))?(?:#(.*))?$/ === url.strip
      new($1 ? $1.downcase : nil, $2 ? $2.downcase : nil, $3 ? $3.to_i : nil, $4, $5, $6)
    else
      nil
    end
  end

  def to_s
    "%s://%s%s" % [protocol, authority, full_path]
  end

  def authority
    "%s%s" % [host, (!port || port == (protocol == "http" ? 80 : 443)) ? "" : ":#{port}"]
  end

  def full_path
    result = path.dup
    result << "?" << query if query
    result << "#" << fragment if fragment
    result
  end

  def join(url)
    url = URL(url)
    if url
      if url.protocol == protocol
        url.protocol = nil
      end
      unless url.protocol
        url.protocol = protocol
        unless url.host
          url.host = host
          url.port = port
          if url.path.empty?
            url.path = path
            unless url.query
              url.query = query
            end
          else
            url.path = join_url_paths(url.path, path)
          end
        end
      end
      url.complete
    else
      nil
    end
  end

  def complete
    self.protocol ||= "http"
    self.port ||= self.protocol == "http" ? 80 : 443
    self.path = "/" if self.path.empty?
    self
  end

  def self.unescape(s)
    s.gsub(/((?:%[0-9a-fA-F]{2})+)/n) do
      [$1.delete('%')].pack('H*')
    end
  end

  def self.escape(s)
    s.to_s.gsub(/([^a-zA-Z0-9_.-]+)/n) do
      '%' + $1.unpack('H2' * $1.size).join('%').upcase
    end
  end

  def self.parse_query(qs, d = '&;')
    params = {}
    (qs || '').split(/[&;] */n).inject(params) do |h, p|
      k, v = unescape(p).split('=', 2)
      if cur = params[k]
        if Array === cur
          params[k] << v
        else
          params[k] = [cur, v]
        end
      else
        params[k] = v
      end
    end
    params
  end

  def self.construct_query(hash)
    hash.map { |k, v| "%s=%s" % [k, escape(v)] }.join('&')
  end

private

  def join_url_paths(url, base)
    if url[0] == ?/
      url
    else
      base[0..base.rindex("/")] + url
    end
  end
end
