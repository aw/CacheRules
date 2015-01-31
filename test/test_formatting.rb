class TestFormatting < MiniTest::Test

  def setup
    @request_headers = {
      "Version"       => "HTTP/1.1",
      "user-agent"    => "test user agent",
      "Cookie"        => "testcookie=deleteme",
      "If-Modified-Since" => "Thu, 01 Jan 2015 07:03:42 GMT",
      "Cache-Control" => "max-stale=1000, no-cache=\"Cookie\", no-store",
      "Referer"       => "http://some.url"
    }
    @cached_headers = {
      "Retry-After" => 60,
      "Cache-Control"     => {
        "public"          => {"token"=>nil, "quoted_string"=>nil},
        "max-stale"       => {"token"=>"1000", "quoted_string"=>nil},
        "no-cache"        => {"token"=>nil, "quoted_string"=>"Cookie"}
      },
      "Last-Modified"     => {"httpdate"=>"Thu, 01 Jan 2015 07:03:42 GMT", "timestamp"=>1420095822},
      "ETag"              => "\"validEtag\""
    }
    @nocache_headers = {"Version"=>"HTTP/1.1", "Set-Cookie"=>"test", "Cookie"=>"test", "Accept-Ranges"=>"test", "Range"=>"test", "If-Range"=>"test", "Content-Range"=>"test", "Referer"=>"http://test.url", "From"=>"test", "Authorization"=>"test", "Proxy-Authorization"=>"test", "User-Agent"=>"test", "If-Modified-Since"=>"invalid date"}
    @duplicate_headers = [
      ['Accept', 'text/html'],
      ['Accept', 'application/json']
    ]
    @non_duplicate_headers = [
      ['Age', '12345'],
      ['Age', '67890']
    ]
    @normalized          = {"Version"=>"HTTP/1.1", "User-Agent"=>"test user agent", "If-Modified-Since"=>{"httpdate"=>"Thu, 01 Jan 2015 07:03:42 GMT", "timestamp"=>1420095822}, "Cache-Control"=>{"max-stale"=>{"token"=>"1000", "quoted_string"=>nil}, "no-cache"=>{"token"=>nil, "quoted_string"=>"Cookie"}, "no-store"=>{"token"=>nil, "quoted_string"=>nil}}}
    @normalized_fields   = [["Version", "HTTP/1.1"], ["user-agent", "test user agent"], ["Cookie", "testcookie=deleteme"], ["If-Modified-Since", {"httpdate"=>"Thu, 01 Jan 2015 07:03:42 GMT", "timestamp"=>1420095822}], ["Cache-Control", {"max-stale"=>{"token"=>"1000", "quoted_string"=>nil}, "no-cache"=>{"token"=>nil, "quoted_string"=>"Cookie"}, "no-store"=>{"token"=>nil, "quoted_string"=>nil}}], ["Referer", "http://some.url"]]
    @unnormalized_fields = {"Retry-After"=>"60", "Cache-Control"=>"public, max-stale=1000, no-cache=\"Cookie\"", "Last-Modified"=>"Thu, 01 Jan 2015 07:03:42 GMT", "ETag"=>"\"validEtag\""}
  end

  def test_normalize
    normalized = CacheRules.normalize.call @request_headers

    assert_kind_of Hash, normalized

    assert_includes normalized, 'Version'
    assert_includes normalized, 'User-Agent'
    assert_includes normalized, 'If-Modified-Since'
    assert_includes normalized, 'Cache-Control'

    assert_equal normalized, @normalized
  end

  def test_format_key
    etag = CacheRules.format_key.call 'etag', 'test value'
    user = CacheRules.format_key.call 'user-agent', 'test user agent'
    vary = CacheRules.format_key.call 'Vary', '*'

    assert_equal etag, ['ETag', 'test value']
    assert_equal user, ['User-Agent', 'test user agent']
    assert_equal vary, ['Vary', '*']
  end

  def test_clean
    cleaned     = CacheRules.clean.call @nocache_headers
    # if_modified = CacheRules.clean.call @nocache_headers
    assert_equal cleaned, [['Version', 'HTTP/1.1'], ['User-Agent', 'test']]
  end

  def test_combine
    combined     = CacheRules.combine.call @duplicate_headers
    not_combined = CacheRules.combine.call @non_duplicate_headers

    assert_equal combined, [['Accept', 'text/html, application/json']]
    assert_equal not_combined, [['Age', '12345']]
  end

  def test_normalize_fields
    normalized = CacheRules.normalize_fields.call @request_headers

    assert_kind_of Array, normalized
    assert_equal normalized, @normalized_fields
  end

  def test_unnormalize_fields
    unnormalized = CacheRules.unnormalize_fields.call @cached_headers

    assert_kind_of Hash, unnormalized
    assert_equal unnormalized, @unnormalized_fields
  end

  def test_format_field
    httpdate        = CacheRules.format_field.call 'If-Modified-Since', @request_headers['If-Modified-Since']
    cache_control   = CacheRules.format_field.call 'Cache-Control', @request_headers['Cache-Control']
    csv             = CacheRules.format_field.call 'Accept', 'text/html, application/json'
    retry_after     = CacheRules.format_field.call 'Retry-After', 60
    retry_after_abs = CacheRules.format_field.call 'Retry-After', -100
    retry_after_date= CacheRules.format_field.call 'Retry-After', 'Thu, 01 Jan 2015 07:03:42 GMT', false
    other           = CacheRules.format_field.call 'Version', @request_headers['Version'], false

    cur_time  = Time.now.gmtime.to_i
    baddate   = CacheRules.format_field.call 'If-Modified-Since', 'invalid date'

    assert_kind_of Array, baddate

    assert_equal httpdate,          ["If-Modified-Since", {"httpdate"=>"Thu, 01 Jan 2015 07:03:42 GMT", "timestamp"=>1420095822}]
    assert_equal cache_control,     ["Cache-Control", {"max-stale"=>{"token"=>"1000", "quoted_string"=>nil}, "no-cache"=>{"token"=>nil, "quoted_string"=>"Cookie"}, "no-store"=>{"token"=>nil, "quoted_string"=>nil}}]
    assert_equal csv,               ["Accept", ["text/html", "application/json"]]
    assert_equal retry_after,       ["Retry-After", 60]
    assert_equal retry_after_abs,   ["Retry-After", 100]
    assert_equal retry_after_date,  ["Retry-After", {"httpdate"=>"Thu, 01 Jan 2015 07:03:42 GMT", "timestamp"=>1420095822}]
    assert_equal other,             ["Version", "HTTP/1.1"]

    assert_in_delta baddate[1]["timestamp"], (cur_time - 300), 2, "Check the httpdate_helper, ensure it's 300 seconds, or increase the delta"
  end

  def test_format_field_string
    cache_control = CacheRules.format_field.call 'Cache-Control', @cached_headers['Cache-Control'], true
    csv           = CacheRules.format_field.call 'Accept', ["text/html", "application/json"], true

    assert_equal cache_control, ["Cache-Control", "public, max-stale=1000, no-cache=\"Cookie\""]
    assert_equal csv,           ["Accept", "text/html, application/json"]
  end

  def test_httpdate_helper
    httpdate = "Sun, 06 Nov 1994 08:49:37 GMT"
    rfc850   = "Sunday, 06-Nov-94 08:49:37 GMT"
    ansi_c   = "Sun Nov 6 08:49:37 1994"
    result   = 784111777

    timestamp1 = CacheRules.httpdate_helper httpdate
    timestamp2 = CacheRules.httpdate_helper rfc850
    timestamp3 = CacheRules.httpdate_helper ansi_c

    assert_equal timestamp1, result
    assert_equal timestamp2, result
    assert_equal timestamp3, result
  end

end
