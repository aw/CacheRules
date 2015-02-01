class TestCacheRules < MiniTest::Test

  def setup
    @request_if_none_match          = CacheRules.normalize.call({ "Host" => "test.com", "If-None-Match" => "*", "Cache-Control" => "max-stale=100000000" })
    @request_if_modified_since_yes  = CacheRules.normalize.call({ "Host" => "test.com", "If-Modified-Since" => "Thu, 01 Jan 2015 07:03:45 GMT", "Cache-Control" => "max-stale=100000000" })
    @request_if_modified_since_no   = CacheRules.normalize.call({ "Host" => "test.com" })
    @cached_headers = {
      "Date"              => {"httpdate"=>"Thu, 01 Jan 2015 07:03:45 GMT", "timestamp"=>1420095825},
      "Cache-Control"     => {
        "public"          => {"token"=>nil, "quoted_string"=>nil}
      },
      "X-Cache-Req-Date"  => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625},
      "X-Cache-Res-Date"  => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}
    }
  end

  def test_get_money
    got_money = CacheRules::Everything::Around::Me.get_the_money

    assert_equal got_money, "Dolla Dolla Bill Y'all"
  end

  def test_validate_column0
    request = {"Host"=>"test.url"}

    result = CacheRules.validate('http://test.url/test1', request)

    assert_equal result[:code], 307
    assert_nil   result[:body]
    assert_equal result[:headers]['Cache-Lookup'], 'MISS'
    assert_equal result[:headers]['Location'], "http://test.url/test1"
  end

  def test_validate_column1
    request = {"Host"=>"test.url","Cache-Control"=>"only-if-cached"}

    result = CacheRules.validate('http://test.url/test1', request)

    assert_equal result[:code], 504
    assert_equal result[:body], 'Gateway Timeout'
    assert_equal result[:headers]['Cache-Lookup'], 'MISS'
  end

  def test_validate_column2
    request = {"Host"=>"test.url"}
    cached  = {"Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Cache-Control"=>{"s-maxage"=>{"token"=>"100000000", "quoted_string"=>nil}}, "X-Cache-Req-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "X-Cache-Res-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Last-Modified" => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}} 

    result = CacheRules.validate('http://test.url/test1', request, cached)

    assert_equal result[:code], 200
    assert_equal result[:body], 'cached'
    assert_equal result[:headers]['Cache-Lookup'], 'HIT'
  end

  def test_validate_column3
    request = {"Host"=>"test.url", "If-None-Match" => "*"}
    cached  = {"Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Cache-Control"=>{"s-maxage"=>{"token"=>"100000000", "quoted_string"=>nil}}, "X-Cache-Req-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "X-Cache-Res-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Last-Modified" => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "ETag" => "\"validEtag\""} 

    result = CacheRules.validate('http://test.url/test1', request, cached)

    assert_equal result[:code], 304
    assert_nil   result[:body]
    assert_equal result[:headers]['Cache-Lookup'], 'HIT'
  end

  def test_validate_column4
    request = {"Host"=>"test.url", "Cache-Control"=>"max-stale=10000000"}
    cached  = {"Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "X-Cache-Req-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "X-Cache-Res-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Last-Modified" => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Last-Modified" => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "ETag" => "\"validEtag\"", "Cache-Control"=>{"max-age"=>{"token"=>"100", "quoted_string" => nil}}} 

    result = CacheRules.validate('http://test.url/test1', request, cached)

    assert_equal result[:code], 200
    assert_equal result[:body], 'stale'
    assert_equal result[:headers]['Cache-Lookup'], 'STALE'
    assert_equal result[:headers]['Warning'], "110 - \"Response is Stale\""
  end

  def test_validate_column5
    request = {"Host"=>"test.url", "Cache-Control"=>"max-stale=10000000", "If-None-Match"=>"*"}
    cached  = {"Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "X-Cache-Req-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "X-Cache-Res-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Last-Modified" => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Last-Modified" => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "ETag" => "\"validEtag\"", "Cache-Control"=>{"max-age"=>{"token"=>"100", "quoted_string" => nil}}} 

    result = CacheRules.validate('http://test.url/test1', request, cached)

    assert_equal result[:code], 304
    assert_nil   result[:body]
    assert_equal result[:headers]['Cache-Lookup'], 'STALE'
    assert_equal result[:headers]['Warning'], "110 - \"Response is Stale\""
  end

  def test_validate_column6
    request = {"Host"=>"test.url", "Cache-Control"=>"max-stale=0", "If-None-Match"=>"*"}
    cached  = {"Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "X-Cache-Req-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "X-Cache-Res-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Last-Modified" => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Last-Modified" => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "ETag" => "\"validEtag\"", "Cache-Control"=>{"max-age"=>{"token"=>"100", "quoted_string" => nil}}} 

    result = CacheRules.validate('http://test.url/test1', request, cached)

    assert_equal result[:code], 504
    assert_equal result[:body], 'Gateway Timeout'
    assert_equal result[:headers]['Cache-Lookup'], 'EXPIRED'
  end

  def test_validate_column7
    request = {"Host"=>"test.url", "Cache-Control"=>"max-stale=0", "If-None-Match"=>"*"}
    cached  = {"Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "X-Cache-Req-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "X-Cache-Res-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Last-Modified" => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Last-Modified" => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "ETag" => "\"validEtag\"", "Cache-Control"=>{"max-age"=>{"token"=>"100", "quoted_string" => nil}, "must-revalidate"=>{"token"=>nil, "quoted_string"=>nil}}} 

    FakeWeb.register_uri(:head, "http://test.url/test1", :status => ["304", "Not Modified"], :date => "Sat, 03 Jan 2015 07:15:45 GMT")
    result = CacheRules.validate('http://test.url/test1', request, cached)

    assert_equal result[:code], 307
    assert_nil   result[:body]
    assert_equal result[:headers]['Cache-Lookup'], 'EXPIRED'
    assert_equal result[:headers]['Location'], "http://test.url/test1"
  end

  def test_validate_column8
    request = {"Host"=>"test.url", "Cache-Control"=>"max-stale=0", "If-None-Match"=>"*"}
    cached  = {"Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "X-Cache-Req-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "X-Cache-Res-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Last-Modified" => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Last-Modified" => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "ETag" => "\"validEtag\"", "Cache-Control"=>{"max-age"=>{"token"=>"100", "quoted_string" => nil}, "no-cache"=>{"token"=>nil, "quoted_string"=>nil}}}

    FakeWeb.register_uri(:head, "http://test.url/test1", :status => ["304", "Not Modified"], :date => "Sat, 03 Jan 2015 07:15:45 GMT")
    result = CacheRules.validate('http://test.url/test1', request, cached)

    assert_equal result[:code], 307
    assert_nil   result[:body]
    assert_equal result[:headers]['Cache-Lookup'], 'EXPIRED'
    assert_equal result[:headers]['Location'], "http://test.url/test1"
  end

  def test_revalidate_response_column0
    request = {"Host"=>"test.url", "If-None-Match"=>["*"], "Cache-Control"=>{"max-age"=>{"token"=>"100000000", "quoted_string"=>nil}}}
    cached  = {"Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Cache-Control"=>{"s-maxage"=>{"token"=>"100000000", "quoted_string"=>nil}}, "X-Cache-Req-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "X-Cache-Res-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Last-Modified" => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}} 

    FakeWeb.register_uri(:head, "http://test.url/test1", :status => ["304", "Not Modified"], :date => "Sat, 03 Jan 2015 07:15:45 GMT", :Warning => "299 - \"Hello World\"")
    result = CacheRules.revalidate_response('http://test.url/test1', request, cached)

    assert_equal result[:code], 200
    assert_equal result[:body], 'cached'
    assert_equal result[:headers]['Cache-Lookup'], 'REVALIDATED'
    assert_equal result[:headers]['Warning'], "299 - \"Hello World\""
  end

  def test_revalidate_response_column1
    request = {"Host"=>"test.url", "If-None-Match"=>["\"validEtag\""], "Cache-Control"=>{"max-age"=>{"token"=>"100000000", "quoted_string"=>nil}}}
    cached  = {"Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Cache-Control"=>{"s-maxage"=>{"token"=>"100000000", "quoted_string"=>nil}}, "X-Cache-Req-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "X-Cache-Res-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Last-Modified" => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "ETag" => "\"validEtag\"", "Content-Type" => "text/html"}

    FakeWeb.register_uri(:head, "http://test.url/test1", :status => ["304", "Not Modified"], :date => "Sat, 03 Jan 2015 07:15:45 GMT", :ETag => "\"validEtag\"", :Warning => "299 - \"Hello World\"")
    result = CacheRules.revalidate_response('http://test.url/test1', request, cached)

    assert_equal result[:code], 304
    assert_nil   result[:body]
    assert_equal result[:headers]['Cache-Lookup'], 'REVALIDATED'
    assert_equal result[:headers]['ETag'], "\"validEtag\""
    assert_equal result[:headers]['Warning'], "299 - \"Hello World\""
    assert_equal result[:headers]['Content-Type'], "text/html"
  end

  def test_revalidate_response_column2_5xx
    request = {"Host"=>"test.url", "If-None-Match"=>["\"validEtag\""], "Cache-Control"=>{"max-age"=>{"token"=>"100000000", "quoted_string"=>nil}}}
    cached  = {"Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Cache-Control"=>{"s-maxage"=>{"token"=>"100000000", "quoted_string"=>nil}}, "X-Cache-Req-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "X-Cache-Res-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Last-Modified" => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "ETag" => "\"validEtag\""} 

    FakeWeb.register_uri(:head, "http://test.url/test1", :status => ["504", "Gateway Timeout"], :date => "Sat, 03 Jan 2015 07:15:45 GMT", :ETag => "\"validEtag\"")
    result = CacheRules.revalidate_response('http://test.url/test1', request, cached)

    assert_equal result[:code], 504
    assert_equal result[:body], 'Gateway Timeout'
    assert_equal result[:headers]['Cache-Lookup'], 'EXPIRED'
  end

  def test_revalidate_response_column2_error
    result = CacheRules.revalidate_response('ftp://test.url/test1', {}, {})

    assert_equal result[:code], 504
    assert_equal result[:body], 'Gateway Timeout'
    assert result[:error]
  end

  def test_revalidate_response_column3
    request = {"Host"=>"test.url", "If-None-Match"=>["*"], "Cache-Control"=>{"max-stale"=>{"token"=>"100000000", "quoted_string"=>nil}}}
    cached  = {"Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "X-Cache-Req-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "X-Cache-Res-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Last-Modified" => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "ETag" => "\"validEtag\""} 

    FakeWeb.register_uri(:head, "http://test.url/test1", :status => ["504", "Gateway Timeout"], :date => "Sat, 03 Jan 2015 07:15:45 GMT")
    result = CacheRules.revalidate_response('http://test.url/test1', request, cached)

    assert_equal result[:code], 200
    assert_equal result[:body], 'stale'
    assert_equal result[:headers]['Warning'], "111 - \"Revalidation Failed\""
    assert_equal result[:headers]['Cache-Lookup'], 'STALE'
  end

  def test_revalidate_response_column4
    request = {"Host"=>"test.url", "If-None-Match"=>["\"validEtag\""], "Cache-Control"=>{"max-stale"=>{"token"=>"100000000", "quoted_string"=>nil}}}
    cached  = {"Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "X-Cache-Req-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "X-Cache-Res-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "Last-Modified" => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "ETag" => "\"validEtag\""} 

    FakeWeb.register_uri(:head, "http://test.url/test1", :status => ["504", "Gateway Timeout"], :date => "Sat, 03 Jan 2015 07:15:45 GMT", :ETag => "\"validEtag\"")
    result = CacheRules.revalidate_response('http://test.url/test1', request, cached)

    assert_equal result[:code], 304
    assert_nil   result[:body]
    assert_equal result[:headers]['Warning'], "111 - \"Revalidation Failed\""
    assert_equal result[:headers]['Cache-Lookup'], 'STALE'
    assert_equal result[:headers]['ETag'], "\"validEtag\""
  end

  def test_revalidate_response_column5
    request = {"Host"=>"test.url", "If-None-Match"=>["*"], "Cache-Control"=>{"max-stale"=>{"token"=>"100000000", "quoted_string"=>nil}}}
    cached  = {"Date"=>{"httpdate"=>"Thu, 01 Jan 2015 07:03:45 GMT", "timestamp"=>1420095825}, "Cache-Control"=>{"public"=>{"token"=>nil, "quoted_string"=>nil}}, "X-Cache-Req-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}, "X-Cache-Res-Date"=>{"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}} 

    FakeWeb.register_uri(:head, "http://test.url/test1", :status => ["200", "OK"])
    result = CacheRules.revalidate_response('http://test.url/test1', request, cached)

    assert_equal result[:code], 307
    assert_nil   result[:body]
    assert_equal result[:headers]['Cache-Lookup'], 'EXPIRED'
    assert_equal result[:headers]['Location'], "http://test.url/test1"
  end

  def test_make_http_request_with_entity_tag
    result  = CacheRules.make_request.call('http://test.url', @request_if_none_match, @cached_headers)
    http    = eval "http",    result.binding
    request = eval "request", result.binding

    assert_kind_of  Proc, result
    assert_kind_of  FalseClass, http.use_ssl?
    assert_equal    http.address, 'test.url'
    assert_equal    http.port, 80
    assert_equal    request.method, 'HEAD'
  end

  def test_make_http_request_with_last_modified
    result  = CacheRules.make_request.call('http://test.url', @request_if_modified_since_yes, @cached_headers)
    http    = eval "http",    result.binding
    request = eval "request", result.binding

    assert_kind_of  Proc, result
    assert_kind_of  FalseClass, http.use_ssl?
    assert_equal    http.address, 'test.url'
    assert_equal    http.port, 80
    assert_equal    request.method, 'HEAD'
  end

  def test_make_http_request_without_preconditions
    result  = CacheRules.make_request.call('https://test.url', @request_if_modified_since_no, @cached_headers)
    http    = eval "http",    result.binding
    request = eval "request", result.binding

    assert_kind_of  Proc, result
    assert_kind_of  TrueClass, http.use_ssl?
    assert_equal    http.address, 'test.url'
    assert_equal    http.port, 443
    assert_equal    request.method, 'HEAD'
  end

  def test_raises_an_error_if_the_url_is_invalid
    assert_raises(SocketError)   { CacheRules.make_request.call('http://test.urlzzz', {}, {}).call }
    assert_raises(NoMethodError) { CacheRules.make_request.call('ftp://test.urlzzz', {}, {}).call }
  end

end
