# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015 Alexander Williams, Unscramble <license@unscramble.jp>

module CacheRules
  extend self

  # HTTP Header Validators
  #
  # Parameters must always be normalized
  #
  # Return must always be 0 or 1
  #
  # The If-Match and If-Unmodified-Since conditional header fields are not applicable to a cache.
  # source: https://tools.ietf.org/html/rfc7234#section-4.3.2

  def to_bit(&predicate)
    predicate.call ? 1 : 0
  end

  def validate_cached?(headers)
    to_bit { headers[:cached].length > 0 }
  end

  # Precedence: If-None-Match (ETag), then If-Modified-Since (Last-Modified)
  # source: https://tools.ietf.org/html/rfc7232#section-6
  def validate_precond_match?(headers)
    request, cached = headers.values_at :request, :cached
    return 0 if cached.length == 0

    # Return when the If-None-Match header exists, ignore If-Modified-Since
    # source: https://tools.ietf.org/html/rfc7232#section-3.3
    etag_match = helper_etag(request, cached)
    return to_bit { etag_match } unless etag_match.nil?

    to_bit { helper_last_modified(request, cached) }
  end

  # Compare headers to see if the cached request is expired (Freshness)
  # source: https://tools.ietf.org/html/rfc7234#section-4.2
  def validate_expired?(headers)
    return 0 if headers[:cached].length == 0

    freshness_lifetime, current_age = helper_freshness_lifetime.call headers[:cached]

    response_is_fresh = freshness_lifetime.to_i > current_age

    return 1 if headers[:cached]['Cache-Control'] &&
                  headers[:cached]['Cache-Control']['max-age'] &&
                    current_age > headers[:cached]['Cache-Control']['max-age']['token'].to_i


    to_bit { (response_is_fresh != true) }
  end

  def validate_only_if_cached?(headers)
    to_bit { headers[:request]['Cache-Control'] && headers[:request]['Cache-Control']['only-if-cached'] }
  end

  # Serving Stale Responses
  # source: https://tools.ietf.org/html/rfc7234#section-4.2.4
  def validate_allow_stale?(headers)
    request, cached = headers.values_at :request, :cached
    return 0 if cached.length == 0 || helper_validate_allow_stale(request, cached)

    freshness_lifetime, current_age = helper_freshness_lifetime.call cached

    max_stale = helper_max_stale.call request['Cache-Control'], freshness_lifetime, current_age
    min_fresh = helper_min_fresh.call request['Cache-Control'], freshness_lifetime, current_age

    to_bit { (max_stale && min_fresh != false) || (max_stale.nil? && min_fresh) }
  end

  # Response Cache-Control Directives
  # source: https://tools.ietf.org/html/rfc7234#section-5.2.2
  def validate_must_revalidate?(headers)
    return 1 if headers[:cached].length == 0

    # source: https://tools.ietf.org/html/rfc7234#section-5.2.2.1
    # source: https://tools.ietf.org/html/rfc7234#section-5.2.2.7
    to_bit { (( cached = headers[:cached]['Cache-Control'] )) && ( cached['must-revalidate'] || cached['proxy-revalidate'] ) }
  end

  # Verify if we're explicitly told not to serve a response without revalidation
  def validate_no_cache?(headers)
    request_headers, cached_headers = headers.values_at :request, :cached
    return 1 if cached_headers.length == 0

    # Must revalidate if this request header exists
    # source: https://tools.ietf.org/html/rfc7234#section-5.2.1.4
    return 1 if (request_headers['Cache-Control'] && request_headers['Cache-Control']['no-cache'])

    _, current_age = helper_freshness_lifetime.call cached_headers

    # If max-age is 0 or if the current age is above the max-age
    # source: https://tools.ietf.org/html/rfc7234#section-5.2.1.1
    return 1 if request_headers['Cache-Control'] &&
                  request_headers['Cache-Control']['max-age'] &&
                    (request_headers['Cache-Control']['max-age']['token'].to_s == "0" || current_age > request_headers['Cache-Control']['max-age']['token'].to_i)

    # source: https://tools.ietf.org/html/rfc7234#section-5.2.2.2
    # source: https://tools.ietf.org/html/rfc7234#section-3.2
    if cached_headers['Cache-Control']
      return 1 if (( cached = cached_headers['Cache-Control'] )) &&
        helper_no_cache.call(cached_headers)                               ||
          (cached['no-cache'] && cached['no-cache']['quoted_string'].nil?) ||
          (cached['s-maxage'] && cached['s-maxage']['token'].to_s == "0")  ||
          (cached['max-age'] && cached['max-age']['token'].to_s   == "0")
    end

    # source: https://tools.ietf.org/html/rfc7234#section-5.4
    # Legacy support for HTTP/1.0 Pragma header
    return 1 if request_headers['Pragma'] && request_headers['Pragma']['no-cache']

    return 0
  end

  def validate_is_error?(headers)
    to_bit { headers[:response]['Status'].to_i.between?(500,599) }
  end

  def validate_validator_match?(headers)
    request, response = headers.values_at :request, :response
    to_bit { response['ETag'] && request['If-None-Match'] && (request['If-None-Match'].include?(response['ETag']) || request['If-None-Match'].include?("*")) }
  end

end
