# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016 Alexander Williams, Unscramble <license@unscramble.jp>
#
# Original Source:  https://github.com/aw/CacheRules
#
#
# This library validates requests and responses for cached HTTP data.
#
# Rules based on RFCs 7230-7235 - https://tools.ietf.org/wg/httpbis/
#
# Usage:
# => CacheRules.validate(url, request_headers, cached_headers)
#
# If you grew up on the crime side:
# => CacheRules::Everything::Around::Me.validate(url, request_headers, cached_headers)

require 'net/http'
require 'date'
require 'time'
require 'uri'

require 'actions.rb'
require 'formatting.rb'
require 'helpers.rb'
require 'validations.rb'

module CacheRules
  extend self

  HEADERS_NO_CACHE = %w(
    Set-Cookie Cookie
    Accept-Ranges Range If-Range Content-Range
    Referer From Host
    Authorization Proxy-Authorization
  )

  HEADERS_HTTPDATE = %w(
    Last-Modified If-Modified-Since If-Unmodified-Since
    Expires Date
    X-Cache-Req-Date X-Cache-Res-Date
  )

  HEADERS_CSV = %w(
    Connection Trailer Transfer-Encoding Upgrade Via
    Accept Accept-Charset Accept-Encoding Accept-Language Allow
    Content-Encoding Content-Language Vary
    Cache-Control Warning Pragma If-Match If-None-Match
  )

  HEADERS_NUMBER = %w(
    Age Content-Length Max-Forwards
  )

  OPTIONS_CACHE = HEADERS_CSV.select {|header| header == 'Cache-Control' }
  OPTIONS_CSV   = HEADERS_CSV.reject {|header| header == 'Cache-Control' }
  OPTIONS_RETRY = %w(Retry-After)

  X = nil

  # Decision table for request/cached headers
  REQUEST_TABLE = {
    :conditions => {
      'cached'          => [0, 0, 1, 1, 1, 1, 1, 1, 1],
      'must_revalidate' => [X, X, X, X, 0, 0, 0, 1, X],
      'no_cache'        => [X, X, 0, 0, 0, 0, 0, 0, 1],
      'precond_match'   => [X, X, 0, 1, 0, 1, X, X, X],
      'expired'         => [X, X, 0, 0, 1, 1, 1, 1, X],
      'only_if_cached'  => [0, 1, X, X, X, X, X, X, X],
      'allow_stale'     => [X, X, X, X, 1, 1, 0, X, X]
    },
    :actions => {
      'revalidate'      => [X, X, X, X, X, X, X, 1, 1],
      'add_age'         => [X, X, 1, 1, 1, 1],
      'add_x_cache'     => %w(MISS MISS HIT HIT STALE STALE EXPIRED),
      'add_warning'     => [X, X, X, X, '110 - "Response is Stale"', '110 - "Response is Stale"'],
      'add_status'      => [307, 504, 200, 304, 200, 304, 504],
      'return_body'     => [X, 'Gateway Timeout', 'cached', X, 'stale', X, 'Gateway Timeout']
    }
  }

  # Decision table for revalidated responses
  RESPONSE_TABLE = {
    :conditions => {
      'is_error'        => [0, 0, 1, 1, 1],
      'allow_stale'     => [X, X, 0, 1, 1],
      'validator_match' => [0, 1, X, 0, 1]
    },
    :actions => {
      'revalidate'      => [],
      'add_age'         => [1, 1, X, 1, 1],
      'add_x_cache'     => %w(REVALIDATED REVALIDATED EXPIRED STALE STALE),
      'add_warning'     => [X, X, X, '111 - "Revalidation Failed"', '111 - "Revalidation Failed"'],
      'add_status'      => [200, 304, 504, 200, 304],
      'return_body'     => ['cached', X, 'Gateway Timeout', 'stale']
    }
  }

  # Build the map tables in advance for faster lookups i.e: O(1)
  REQUEST_MAP   = helper_table_map(REQUEST_TABLE[:conditions])
  RESPONSE_MAP  = helper_table_map(RESPONSE_TABLE[:conditions])

  # Public: Validate a URL and the request/cached/response headers
  # TODO: validate the required parameters to ensure they are set correctly
  def validate(url, request_headers, cached_headers = {})
    # 1. normalize the request headers
    normalized_headers = normalize.call request_headers
    actions            = REQUEST_TABLE[:actions]

    # 2. get the column matching the request headers
    column = REQUEST_MAP[helper_run_validate.call(REQUEST_TABLE[:conditions], normalized_headers, cached_headers).join]
    response    = Proc.new { helper_response url, actions, column, cached_headers }
    revalidate  = Proc.new { revalidate_response url, normalized_headers, cached_headers }

    # 3. return the response or revalidate
    actions['revalidate'][column] == 1 ? revalidate.call : response.call
  end

  # Revalidates a response by fetching headers from the origin server
  def revalidate_response(*args)
    url, request, cached = *args
    has_preconditions    = helper_has_preconditions.(request, cached)

    # 1. get the column
    column = if has_preconditions
      res_headers = helper_response_headers.(helper_make_request_timer.(args))
      RESPONSE_MAP[helper_run_validate.call(RESPONSE_TABLE[:conditions], request, cached, res_headers).join]
    else
      res_headers = {}
      2 # return column 2 (504 EXPIRED)
    end

    # 2. return the response
    helper_response url, RESPONSE_TABLE[:actions], column, cached, res_headers
  rescue => error
    {:code => 504, :body => 'Gateway Timeout', :headers => [], :error => error.message, :debug => error}
  end

  # Returns a net/http response Object
  def make_request
    ->(url, request_headers, cached_headers) {
      uri               = URI.parse url
      http              = Net::HTTP.new uri.host, uri.port
      http.open_timeout = 2
      http.read_timeout = 60
      http.use_ssl      = uri.scheme == 'https'
      http.verify_mode  = OpenSSL::SSL::VERIFY_PEER

      request           = Net::HTTP::Head.new uri.request_uri

      # Two possible validators: entity tags and timestamp
      # source: https://tools.ietf.org/html/rfc7234#section-4.3.1
      entity_tags = Proc.new { helper_combine_etags request_headers, cached_headers }.call
      timestamp   = Proc.new { helper_timestamp     request_headers, cached_headers }

      # Set the precondition header before making the request
      request['If-None-Match'] = entity_tags if entity_tags
      ts = timestamp.call unless entity_tags
      request['If-Modified-Since'] = ts if ts && !entity_tags

      # Make the HTTP(s) request
      helper_make_request http, request
    }
  end

end

module CacheRules
  module Everything
    module Around
      module Me
        extend CacheRules

        # C.R.E.A.M.
        def self.get_the_money
          "Dolla Dolla Bill Y'all"
        end

      end
    end
  end
end
