# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2016 Alexander Williams, Unscramble <license@unscramble.jp>

module CacheRules
  extend self

  # Create a map with all possible combinations
  def helper_table_map(conditions)
    (2**conditions.length).times.map(&helper_row_col_hash(conditions)).reduce(:merge)
  end

  # Returns a hash representing a row/column, for the table map
  def helper_row_col_hash(conditions)
    Proc.new {|index|
      row = helper_bit_string conditions.length, index
      col = helper_parse_conditions({:conditions => conditions, :answers => row.chars.map(&:to_i)})

      {row => col}
    }
  end

  # Returns a string of 0s and 1s
  def helper_bit_string(num_conditions, index)
    index.to_s(2).rjust num_conditions, '0'
  end

  # Returns the matching column number, or nil
  def helper_parse_conditions(table)
    # Loop through each answer and hope to end up with the exact column match
    result = table[:answers].each_index.map(&helper_loop_conditions(table)).reduce(:&).compact
    result[0] if result.length == 1
  end

  # Loop through each condition and see if the answer matches
  def helper_loop_conditions(table)
    Proc.new {|index|
      table[:conditions].values[index].map.each_with_index {|x, i|
        i if x == table[:answers][index] || x.nil?
      }
    }
  end

  # Returns a bit Array of answers for the conditions
  def helper_run_validate
    Proc.new {|table, request, cached, response|
      table.keys.map {|x|
        headers = {:request => request, :cached => cached, :response => response}
        send("validate_#{ x }?", headers)
      }
    }
  end

  # Returns an Array of actions to be performed based on the column number
  def helper_run_action(actions, column, cached)
    actions.map {|key, value|
      send("action_#{ key }", {:value => value[column], :cached => cached}) unless value[column].nil?
    }
  end

  # Returns the response body, code and headers based on the actions results
  def helper_response(url, actions, column, cached, response = {})
    _, age, x_cache, warning, status, body = helper_run_action actions, column, cached

    normalized    = normalize.call response
    headers_304   = helper_headers_200_304.call(cached, normalized) if status == 200 || status == 304
    headers_url   = {'Location' => url}                             if status == 307

    headers       = [headers_304, age, warning, x_cache, headers_url].compact.reduce &:merge

    {:body => body, :code => status, :headers => headers}
  end

  # Returns a Boolean after trying to parse the If-Modified-Since, or nil
  def helper_is_if_modified_error?(key, value)
    if key == 'If-Modified-Since'
      begin
        false if DateTime.parse(value)
      rescue ArgumentError => e
        true
      end
    end
  end

  # Generate the same headers if they exist for 200/304 responses
  # source: https://tools.ietf.org/html/rfc7232#section-4.1
  def helper_headers_200_304
    Proc.new {|cached, response|
      new_headers = response.select &helper_remove_warning_1xx
      unnormalize_fields.call cached.merge(new_headers).reject {|key, _|
        key == 'X-Cache-Req-Date' || key == 'X-Cache-Res-Date' || key == 'Status'
      }
    }
  end

  # delete 1xx Warning headers
  # source: https://tools.ietf.org/html/rfc7234#section-4.3.4
  def helper_remove_warning_1xx
    Proc.new {|key, value|
      {key => value} unless key == 'Warning' && value.reject! {|x| x =~ /^1\d{2}/ } && value.length == 0
    }
  end

  # Header can be a String or Array
  def helper_has_star(header)
    header && header.include?("*")
  end

  # Combine entity tags if they exist
  # source: https://tools.ietf.org/html/rfc7234#section-4.3.2
  def helper_combine_etags(request, cached)
    return "*" if helper_has_star(request['If-None-Match'])

    request['If-None-Match'] ? request['If-None-Match'].push(cached['ETag']).uniq.compact.join(', ') : cached['ETag']
  end

  # Use the last modified date if it exists
  # source: https://tools.ietf.org/html/rfc7234#section-4.3.2
  def helper_timestamp(request, cached)
    return request['If-Modified-Since']['httpdate'] if request['If-Modified-Since']

    cached['Last-Modified']['httpdate'] if cached['Last-Modified']
  end

  # source: https://tools.ietf.org/html/rfc7232#section-2.3
  def helper_weak_compare
    etag = /^(W\/)?(\"\w+\")$/

    ->(etag1, etag2) {
      # source: https://tools.ietf.org/html/rfc7232#section-2.3.2
      opaque_tag1 = etag.match etag1
      opaque_tag2 = etag.match etag2

      return false if opaque_tag1.nil? || opaque_tag2.nil?

      opaque_tag1[2] == opaque_tag2[2]
    }
  end

  # Must use the 'weak comparison' function
  # source: https://tools.ietf.org/html/rfc7232#section-3.2
  def helper_etag_match(request, cached)
    return unless request && cached

    request.any? {|x|
      helper_weak_compare.call(x, cached)
    }
  end

  # It is not possible for a response's ETag to contain a "star", don't check for it
  # source: https://tools.ietf.org/html/rfc7232#section-2.3.2
  def helper_etag(request, cached)
    helper_has_star(request['If-None-Match']) || helper_etag_match(request['If-None-Match'], cached['ETag'])
  end

  # source: https://tools.ietf.org/html/rfc7232#section-3.3
  def helper_last_modified(request, cached)
    rules = {
      :response_time         => cached['X-Cache-Res-Date']['timestamp'],   # Required
      :date_value            => (cached['Date']['timestamp']               if cached['Date']),
      :cached_last_modified  => (cached['Last-Modified']['timestamp']      if cached['Last-Modified']),
      :if_modified_since     => (request['If-Modified-Since']['timestamp'] if request['If-Modified-Since'])
    }
    return unless rules[:if_modified_since]

    return true if
      helper_304_rule1(rules) ||
      helper_304_rule2(rules) ||
      helper_304_rule3(rules) ||
      helper_304_rule4(rules)

  end

  # "A cache recipient SHOULD generate a 304 (Not Modified) response if..."
  # source: https://tools.ietf.org/html/rfc7234#section-4.3.2
  def helper_304_rule1(rules)
    rules[:cached_last_modified] &&
    rules[:cached_last_modified] <= rules[:if_modified_since]
  end

  def helper_304_rule2(rules)
    rules[:cached_last_modified].nil? &&
    rules[:date_value] &&
    rules[:date_value] <= rules[:if_modified_since]
  end

  def helper_304_rule3(rules)
    rules[:date_value].nil? &&
    rules[:cached_last_modified].nil? &&
    rules[:response_time] <= rules[:if_modified_since]
  end

  # "The presented Last-Modified time is at least 60 seconds before the Date value." ¯\_(ツ)_/¯
  # source: https://tools.ietf.org/html/rfc7232#section-2.2.2
  def helper_304_rule4(rules)
    rules[:if_modified_since] &&
    rules[:date_value] &&
    rules[:if_modified_since] <= (rules[:date_value] - 60)
  end

  # Don't allow stale if no-cache or no-store headers exist
  # source: https://tools.ietf.org/html/rfc7234#section-4.2.4
  def helper_validate_allow_stale(request_headers, cached_headers)
    return true if (( request = request_headers['Cache-Control'] )) &&
      ( request['no-cache'] || request['no-store'] )

    return true if (( cached = cached_headers['Cache-Control'] )) &&
      ( cached['no-cache'] ||
        cached['no-store'] ||
        cached['must-revalidate'] ||
        cached['s-maxage'] ||
        cached['proxy-revalidate'] )

    # Legacy support for HTTP/1.0 Pragma header
    # source: https://tools.ietf.org/html/rfc7234#section-5.4
    return true if request_headers['Pragma'] == 'no-cache'
  end

  def helper_apparent_age(response_time, date_value)
    Proc.new {
      [0, (response_time - date_value)].max
    }
  end

  def helper_corrected_age_value(response_time, request_time, age_value)
    Proc.new {
      # NOTE: It's technically IMPOSSIBLE for response_time to be LOWER THAN request_time
      response_delay = response_time - request_time
      age_value + response_delay
    }
  end

  def helper_corrected_initial_age(cached, corrected_age_value, apparent_age)
    Proc.new {
      if cached['Via'] && cached['Age'] && cached['Via'].none? {|x| x.match /1\.0/ }
        # corrected_age_value.call
        [0, corrected_age_value.call].max # safeguard just in case
      else
        [apparent_age.call, corrected_age_value.call].max
    end
    }
  end

  # Calculate the current_age of the cached response
  # source: https://tools.ietf.org/html/rfc7234#section-4.2.3
  def helper_current_age(now, cached)
    date_value            = cached['Date']['timestamp']             # Required
    request_time          = cached['X-Cache-Req-Date']['timestamp'] # Required
    response_time         = cached['X-Cache-Res-Date']['timestamp'] # Required
    age_value             = cached['Age'].nil? ? 0 : cached['Age'].to_i

    apparent_age          = helper_apparent_age           response_time, date_value
    corrected_age_value   = helper_corrected_age_value    response_time, request_time, age_value
    corrected_initial_age = helper_corrected_initial_age  cached, corrected_age_value, apparent_age

    resident_time = now - response_time
    corrected_initial_age.call + resident_time
  end

  # Calculate the Freshness Lifetime of the cached response
  # source: https://tools.ietf.org/html/rfc7234#section-4.2.1
  def helper_freshness_lifetime
    now = Time.now.gmtime.to_i

    ->(cached) {
      current_age = helper_current_age now, cached

      # source: https://tools.ietf.org/html/rfc7234#section-4.2
      freshness_lifetime = helper_explicit(cached) || helper_heuristic(now, cached, current_age)

      [freshness_lifetime, current_age]
    }
  end

  # If the expire times are explicitly declared
  # source: https://tools.ietf.org/html/rfc7234#section-4.2.1
  def helper_explicit(cached_headers)
    if (( cached = cached_headers['Cache-Control'] ))
      return cached['s-maxage']['token'] if cached['s-maxage']
      return cached['max-age']['token']  if cached['max-age']
    end

    return (cached_headers['Expires']['timestamp'] - cached_headers['Date']['timestamp']) if cached_headers['Expires']
  end

  # Calculate Heuristic Freshness if there's no explicit expiration time
  # source: https://tools.ietf.org/html/rfc7234#section-4.2.2
  def helper_heuristic(now, cached, current_age)
    # Use 10% only if there's a Last-Modified header
    # source: https://tools.ietf.org/html/rfc7234#section-4.2.2
    if cached['Last-Modified']
      result = (now - cached['Last-Modified']['timestamp']) / 10

      # Don't return heuristic responses more than 24 hours old, and avoid sending a 113 Warning ;)
      # source: https://tools.ietf.org/html/rfc7234#section-4.2.2
      current_age > 86400 ? 0 : result
    else
      0
    end
  end

  # source: https://tools.ietf.org/html/rfc7234#section-5.2.1.2
  def helper_max_stale
    ->(request, freshness_lifetime, current_age) {
      if request && request['max-stale']
        token = request['max-stale']['token']
        token ? (freshness_lifetime.to_i + token.to_i) > current_age : true
      else
        true
      end
    }
  end

  # source: https://tools.ietf.org/html/rfc7234#section-5.2.1.3
  def helper_min_fresh
    Proc.new {|request, freshness_lifetime, current_age|
      if request && request['min-fresh']
        token = request['min-fresh']['token']
        freshness_lifetime.to_i >= (current_age + token.to_i)
      end
    }
  end

  # source: https://tools.ietf.org/html/rfc7234#section-5.2.2.2
  def helper_no_cache
    Proc.new {|cached_headers|
      nocache = cached_headers['Cache-Control']['no-cache']
      # "If the no-cache response directive specifies one or more field-names..."
      (nocache && nocache['quoted_string']) &&
        nocache['quoted_string'].split(',').map(&:strip).length > 0
    }
  end

  def helper_make_request(http, request)
    Proc.new { http.request request }
  end

  def helper_make_request_timer
    Proc.new {|url, request, cached|
      {
        :req_date  => Time.now.gmtime.httpdate,
        :res       => make_request.call(url, request, cached).call,
        :res_date  => Time.now.gmtime.httpdate
      }
    }
  end

  def helper_response_headers
    Proc.new {|result|
      res_headers = normalize.(result[:res].to_hash.map &:flatten)

      res_headers['Date']             = result[:res_date] if res_headers['Date']
      res_headers['X-Cache-Req-Date'] = result[:req_date]
      res_headers['X-Cache-Res-Date'] = result[:res_date]
      res_headers['Status']           = result[:res].code

      res_headers
    }
  end

  # The validators are required for revalidation
  # source: https://tools.ietf.org/html/rfc7232#section-2
  def helper_has_preconditions
    Proc.new {|request, cached|
      request['If-None-Match'] || cached['ETag'] || cached['Last-Modified']
    }
  end
end
