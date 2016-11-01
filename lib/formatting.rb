# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016 Alexander Williams, Unscramble <license@unscramble.jp>

module CacheRules
  extend self

  # HTTP Header Formatting

  # Create a normalized Hash of HTTP headers
  def normalize
    ->(headers) {
      Hash[normalize_fields.(combine.(clean.(Array(headers).map &format_key)))]
    }
  end

  # Format the key to look like this: Last-Modified
  def format_key
    Proc.new {|key, value|
      k = key.downcase == 'etag' ? 'ETag' : key.split('-').map(&:capitalize).join('-')
      [ k, value ]
    }
  end

  # Intentionally drop these headers to avoid caching them
  # If-Modified-Since should be dropped if the date isn't valid
  # source: https://tools.ietf.org/html/rfc7232#section-3.3
  def clean
    ->(headers) {
      Array(headers).reject {|key, value|
        HEADERS_NO_CACHE.include?(key) || helper_is_if_modified_error?(key, value) || value.nil? || value.empty?
      }
    }
  end

  # Combine headers with a comma if the field-names are duplicate
  def combine
    ->(headers) {
      Array(headers).group_by {|h, _| h }.map {|k, v|
        v = HEADERS_CSV.include?(k) ? v.map {|_, x| x }.join(', ') : v[0][1] # OPTIMIZE
        [ k, v ]
      }
    }
  end

  # Normalizes the value (field-value) of each header
  def normalize_fields
    ->(headers) {
      Array(headers).map &format_field
    }
  end

  # Returns a Hash of Strings
  def unnormalize_fields
    ->(headers) {
      Array(headers).reduce({}) {|hash, (key, value)|
        hash.merge Hash[[format_field.call(key, value, true)]]
      }
    }
  end

  # Returns a Hash, Array, Integer or String based on the supplied arguments
  def format_field
    Proc.new {|key, header, stringify|
      f = format_value header, stringify

      value = case key
        when *HEADERS_HTTPDATE then f.call('httpdate')      # => Hash
        when *OPTIONS_CACHE    then f.call('cache_control') # => Array
        when *OPTIONS_CSV      then f.call('csv')           # => Array
        when *OPTIONS_RETRY    then f.call('retry_after')   # => Hash or Integer
        else header                                         # => String
      end
      [ key, value ]
    }
  end

  # Returns the value of the field
  def format_value(header, stringify = nil)
    Proc.new {|field|
      stringify ? send("#{ field }_string", header) : send("#{ field }", header)
    }
  end

  def httpdate(header)
    timestamp = httpdate_helper header

    {
      'httpdate'  => Time.at(timestamp).gmtime.httpdate,
      'timestamp' => timestamp
    }
  end

  def httpdate_string(header)
    timestamp = httpdate_helper header['httpdate']

    Time.at(timestamp).gmtime.httpdate
  end

  # Correctly parse the 3 Date/Time formats and convert to GMT
  # source: https://tools.ietf.org/html/rfc7234#section-4.2
  def httpdate_helper(header)
    # source: https://tools.ietf.org/html/rfc7231#section-7.1.1.1
    DateTime.parse(header).to_time.to_i
  rescue => e
    # If the supplied date is invalid, use a time in the past (5 minutes ago)
    # source: https://tools.ietf.org/html/rfc7234#section-5.3
    Time.now.gmtime.to_i - 300
  end

  # OPTIMIZE: this regex is copied from JavaScript, could be greatly simplified
  # Returns a Hash with the directive as key, token (or nil), quoted-string (or nil)
  def cache_control(header = '')
    result = header.scan /(?:^|(?:\s*\,\s*))([^\x00-\x20\(\)<>@\,;\:\\"\/\[\]\?\=\{\}\x7F]+)(?:\=(?:([^\x00-\x20\(\)<>@\,;\:\\"\/\[\]\?\=\{\}\x7F]+)|(?:\"((?:[^"\\]|\\.)*)\")))?/
    result.reduce({}) {|hash, x|
      hash.merge({
        x[0].downcase => {
          'token'         => x[1],
          'quoted_string' => x[2]
        }
      })
    }
  end

  # Parses the Cache-Control header and returns a comma-separated String
  def cache_control_string(header)
    Array(header).map {|x|
      token     = x[1]['token']
      quote     = x[1]['quoted_string']
      directive = x[0]

      if    token && quote.nil? then "#{ directive }=#{ token }"
      elsif token.nil? && quote then "#{ directive }=\"#{ quote }\""
      else  directive
      end
    }.join ', '
  end

  def csv(header = '')
    header.split(',').map(&:strip)
  end

  def csv_string(header)
    Array(header).join ', '
  end

  # "The value of this field can be either an HTTP-date or a number of seconds..."
  # source: https://tools.ietf.org/html/rfc7234#section-7.1.3
  def retry_after(header)
    Integer(header).abs
  rescue => e
    httpdate header
  end

  def retry_after_string(header)
    header.to_s
  end

end
