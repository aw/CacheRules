class TestHelpers < MiniTest::Test

  def setup
    cache_control   = {"max-stale"=>{"token"=>"1000", "quoted_string"=>nil}, "no-cache"=>{"token"=>nil, "quoted_string"=>nil}}
    if_modified     = {"httpdate"=>"Thu, 01 Jan 2015 07:03:42 GMT", "timestamp"=>1420095822}
    date            = {"httpdate"=>"Fri, 02 Jan 2015 11:03:45 GMT", "timestamp"=>1420196625}
    date_minus_60   = {"httpdate"=>"Fri, 02 Jan 2015 11:02:45 GMT", "timestamp"=>1420196565}
    next_date       = {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}
    if_modified_new = {"httpdate"=>"Sun, 04 Jan 2015 09:03:45 GMT", "timestamp"=>1420362225}

    @request_headers = {
      "If-Modified-Since" => if_modified,
      "Cache-Control" => cache_control,
      "If-None-Match" => ["*"]
    }
    @request_headers_new = {
      "If-Modified-Since" => if_modified_new,
      "Cache-Control" => cache_control,
      "If-None-Match" => ["*"]
    }
    @request_headers_60 = {
      "If-Modified-Since" => date_minus_60,
      "Cache-Control" => cache_control,
      "If-None-Match" => ["*"]
    }
    @request_headers_combine = {
      "If-Modified-Since" => if_modified,
      "Cache-Control" => cache_control,
      "If-None-Match" => ["\"myetag\"", "\"validEtag\""]
    }
    @request_headers_combine_nothing = {
      "Cache-Control" => cache_control
    }
    @request_headers_nothing = {
      "If-None-Match" => ["\"myetag\""] 
    }
    @cached_headers = {
      "Date"              => date,
      "Cache-Control"     => {
        "public"          => {"token"=>nil, "quoted_string"=>nil},
        "max-stale"       => {"token"=>"1000", "quoted_string"=>nil},
        "no-cache"        => {"token"=>nil, "quoted_string"=>"Cookie"}
      },
      "Last-Modified"     => date,
      "X-Cache-Req-Date"  => next_date,
      "X-Cache-Res-Date"  => next_date,
      "ETag"              => "\"validEtag\""
    }
    @cached_rule2 = {
      "Date"              => date,
      "X-Cache-Res-Date"  => next_date
    }
    @cached_rule3 = {
      "X-Cache-Res-Date"  => next_date
    }
  end

  def test_run_validate
    is_proc = CacheRules.helper_run_validate
    result  = is_proc.call CacheRules::REQUEST_TABLE[:conditions], @request_headers, @cached_headers, nil

    assert_kind_of Proc, is_proc
    assert_kind_of Array, result
    assert_equal result, [1, 0, 1, 1, 1, 0, 0]
  end

  def test_response_request
    url = 'http://test.url'
    act = CacheRules::REQUEST_TABLE[:actions]

    column0 = CacheRules.helper_response url, act, 0, @cached_headers
    column1 = CacheRules.helper_response url, act, 1, @cached_headers
    column2 = CacheRules.helper_response url, act, 2, @cached_headers
    column3 = CacheRules.helper_response url, act, 3, @cached_headers
    column4 = CacheRules.helper_response url, act, 4, @cached_headers
    column5 = CacheRules.helper_response url, act, 5, @cached_headers
    column6 = CacheRules.helper_response url, act, 6, @cached_headers
    column7 = CacheRules.helper_response url, act, 7, @cached_headers
    column8 = CacheRules.helper_response url, act, 8, @cached_headers

    assert_equal column0, {:body=>nil, :code=>307, :headers=>{"Cache-Lookup"=>"MISS", "Location"=>"http://test.url"}}
    assert_equal column1, {:body=>"Gateway Timeout", :code=>504, :headers=>{"Cache-Lookup"=>"MISS"}}

    assert_equal column2[:body], 'cached'
    assert_equal column2[:code], 200
    assert_equal column2[:headers]['Cache-Lookup'], 'HIT'
    assert_includes column2[:headers], 'Age'

    assert_nil column3[:body]
    assert_equal column3[:code], 304
    assert_equal column3[:headers]['Cache-Lookup'], 'HIT'
    assert_equal column3[:headers]['Date'], "Fri, 02 Jan 2015 11:03:45 GMT"
    assert_equal column3[:headers]['Cache-Control'], "public, max-stale=1000, no-cache=\"Cookie\""
    assert_equal column3[:headers]['ETag'], "\"validEtag\""
    assert_includes column3[:headers], 'Age'

    assert_equal column4[:body], 'stale'
    assert_equal column4[:code], 200
    assert_equal column4[:headers]['Cache-Lookup'], 'STALE'
    assert_equal column4[:headers]['Warning'], "110 - \"Response is Stale\""
    assert_includes column4[:headers], 'Age'

    assert_nil column5[:body]
    assert_equal column5[:code], 304
    assert_equal column5[:headers]['Cache-Lookup'], 'STALE'
    assert_equal column5[:headers]['Warning'], "110 - \"Response is Stale\""
    assert_equal column5[:headers]['Date'], "Fri, 02 Jan 2015 11:03:45 GMT"
    assert_equal column5[:headers]['Cache-Control'], "public, max-stale=1000, no-cache=\"Cookie\""
    assert_equal column5[:headers]['ETag'], "\"validEtag\""
    assert_includes column5[:headers], 'Age'

    assert_equal column6, {:body=>"Gateway Timeout", :code=>504, :headers=>{"Cache-Lookup"=>"EXPIRED"}}
    assert_equal column7, {:body=>nil, :code=>nil, :headers=>nil}
    assert_equal column8, {:body=>nil, :code=>nil, :headers=>nil}

    assert_kind_of String, column2[:headers]['Age']
  end

  def test_response_revalidate
    url = 'http://test.url'
    act = CacheRules::RESPONSE_TABLE[:actions]

    column0 = CacheRules.helper_response url, act, 0, @cached_headers
    column1 = CacheRules.helper_response url, act, 1, @cached_headers
    column2 = CacheRules.helper_response url, act, 2, @cached_headers
    column3 = CacheRules.helper_response url, act, 3, @cached_headers
    column4 = CacheRules.helper_response url, act, 4, @cached_headers
    column5 = CacheRules.helper_response url, act, 5, @cached_headers

    assert_equal column0[:body], 'cached'
    assert_equal column0[:code], 200
    assert_equal column0[:headers]['Cache-Lookup'], 'REVALIDATED'
    assert_includes column0[:headers], 'Age'

    assert_nil column1[:body]
    assert_equal column1[:code], 304
    assert_equal column1[:headers]['Cache-Lookup'], 'REVALIDATED'
    assert_equal column1[:headers]['Date'], "Fri, 02 Jan 2015 11:03:45 GMT"
    assert_equal column1[:headers]['Cache-Control'], "public, max-stale=1000, no-cache=\"Cookie\""
    assert_equal column1[:headers]['ETag'], "\"validEtag\""
    assert_includes column1[:headers], 'Age'

    assert_equal column2, {:body=>"Gateway Timeout", :code=>504, :headers=>{"Cache-Lookup"=>"EXPIRED"}}

    assert_equal column3[:body], 'stale'
    assert_equal column3[:code], 200
    assert_equal column3[:headers]['Cache-Lookup'], 'STALE'
    assert_equal column3[:headers]['Warning'], "111 - \"Revalidation Failed\""
    assert_includes column3[:headers], 'Age'

    assert_nil column4[:body]
    assert_equal column4[:code], 304
    assert_equal column4[:headers]['Cache-Lookup'], 'STALE'
    assert_equal column4[:headers]['Warning'], "111 - \"Revalidation Failed\""
    assert_equal column4[:headers]['Date'], "Fri, 02 Jan 2015 11:03:45 GMT"
    assert_equal column4[:headers]['Cache-Control'], "public, max-stale=1000, no-cache=\"Cookie\""
    assert_equal column4[:headers]['ETag'], "\"validEtag\""
    assert_includes column4[:headers], 'Age'

    assert_equal column5, {:body=>nil, :code=>307, :headers=>{"Cache-Lookup"=>"EXPIRED", "Location"=>"http://test.url"}}

    assert_kind_of String, column0[:headers]['Age']
  end

  def test_is_if_modified_error
    not_error = CacheRules.helper_is_if_modified_error? 'If-Modified-Since', "Fri, 02 Jan 2015 11:03:45 GMT"
    is_error  = CacheRules.helper_is_if_modified_error? 'If-Modified-Since', "invalid date"
    noop      = CacheRules.helper_is_if_modified_error? 'Not-Even-A-Key', "test"

    assert_kind_of FalseClass, not_error
    assert_kind_of TrueClass, is_error
    assert_nil noop
  end

  def test_headers_304
    headers = CacheRules.helper_headers_304.call @cached_headers

    assert_kind_of Hash, headers

    assert_equal headers, {"Date"=>"Fri, 02 Jan 2015 11:03:45 GMT", "Cache-Control"=>"public, max-stale=1000, no-cache=\"Cookie\"", "ETag"=>"\"validEtag\""}
  end

  def test_helper_has_star
    ystar   = CacheRules.helper_has_star "*"
    nstar   = CacheRules.helper_has_star "myetag"
    ymulti  = CacheRules.helper_has_star ["test", "*"]
    nmulti  = CacheRules.helper_has_star ["test1", "test2"]

    assert_kind_of TrueClass,  ystar
    assert_kind_of FalseClass, nstar
    assert_kind_of TrueClass,  ymulti
    assert_kind_of FalseClass, nmulti
  end

  def test_combine_etags
    star    = CacheRules.helper_combine_etags @request_headers, @cached_headers
    match   = CacheRules.helper_combine_etags @request_headers_combine, @cached_headers
    nomatch = CacheRules.helper_combine_etags @request_headers_combine_nothing, @cached_headers

    assert_equal star,    "*"
    assert_equal match,   "\"myetag\", \"validEtag\""
    assert_equal nomatch, "\"validEtag\""
  end

  def test_timestamp
    request     = CacheRules.helper_timestamp @request_headers, @cached_headers
    cached      = CacheRules.helper_timestamp @request_headers_combine_nothing, @cached_headers
    nothing     = CacheRules.helper_timestamp({}, {})

    assert_nil nothing

    assert_equal request, "Thu, 01 Jan 2015 07:03:42 GMT"
    assert_equal cached,  "Fri, 02 Jan 2015 11:03:45 GMT"
  end

  def test_etag
    etag_match    = CacheRules.helper_etag @request_headers, @cached_headers
    etag_nomatch  = CacheRules.helper_etag @request_headers_combine_nothing, @cached_headers
    etag_combined = CacheRules.helper_etag @request_headers_combine, @cached_headers
    etag_nothing  = CacheRules.helper_etag @request_headers_nothing, @cached_headers

    assert_kind_of TrueClass,  etag_match
    assert_nil etag_nomatch
    assert_kind_of TrueClass,  etag_combined
    assert_kind_of FalseClass, etag_nothing
  end

  def test_last_modified
    guard = CacheRules.helper_last_modified @request_headers_combine_nothing, @cached_headers
    rule1 = CacheRules.helper_last_modified @request_headers_new, @cached_headers
    rule2 = CacheRules.helper_last_modified @request_headers_new, @cached_rule2
    rule3 = CacheRules.helper_last_modified @request_headers_new, @cached_rule3
    rule4 = CacheRules.helper_last_modified @request_headers_60,  @cached_headers

    assert_nil guard
    assert_kind_of TrueClass, rule1
    assert_kind_of TrueClass, rule2
    assert_kind_of TrueClass, rule3
    assert_kind_of TrueClass, rule4
  end

  def test_validate_allow_stale
    no_cache  = CacheRules.helper_validate_allow_stale @request_headers, @cached_headers
    no_store  = CacheRules.helper_validate_allow_stale({"Cache-Control" => {"no-store"=>{"token"=>nil, "quoted_string"=>nil}}}, @cached_headers)
    pragma    = CacheRules.helper_validate_allow_stale({"Pragma" => "no-cache"}, @cached_rule2)

    cached_no_cache = CacheRules.helper_validate_allow_stale({}, @cached_headers)
    cached_no_store = CacheRules.helper_validate_allow_stale({}, {"Cache-Control" => {"no-store"=>{"token"=>nil, "quoted_string"=>nil}}})
    cached_must_rev = CacheRules.helper_validate_allow_stale({}, {"Cache-Control" => {"must-revalidate"=>{"token"=>nil, "quoted_string"=>nil}}})
    cached_s_maxage = CacheRules.helper_validate_allow_stale({}, {"Cache-Control" => {"s-maxage"=>{"token"=>nil, "quoted_string"=>nil}}})
    cached_proxy_re = CacheRules.helper_validate_allow_stale({}, {"Cache-Control" => {"proxy-revalidate"=>{"token"=>nil, "quoted_string"=>nil}}})

    nothing = CacheRules.helper_validate_allow_stale({}, @cached_rule2)

    assert_kind_of TrueClass, no_cache
    assert_kind_of TrueClass, no_store
    assert_kind_of TrueClass, pragma

    assert_kind_of TrueClass, cached_no_cache
    assert_kind_of TrueClass, cached_no_store
    assert_kind_of TrueClass, cached_must_rev
    assert_kind_of TrueClass, cached_s_maxage
    assert_kind_of TrueClass, cached_proxy_re

    assert_nil nothing
  end

  def test_apparent_age
    older   = CacheRules.helper_apparent_age(1420196565, 1420196505).call
    current = CacheRules.helper_apparent_age(1420196565, 1420196565).call
    newer   = CacheRules.helper_apparent_age(1420196505, 1420196565).call

    assert_equal older,   60
    assert_equal current, 0
    assert_equal newer,   0
  end

  def test_corrected_age_value
    zero        = CacheRules.helper_corrected_age_value(1420196565, 1420196565, 0).call
    one_hundred = CacheRules.helper_corrected_age_value(1420196565, 1420196565, 100).call
    sixty       = CacheRules.helper_corrected_age_value(1420196565, 1420196505, 0).call
    one_sixty   = CacheRules.helper_corrected_age_value(1420196565, 1420196505, 100).call
    impossible  = CacheRules.helper_corrected_age_value(1420196505, 1420196565, 0).call

    assert_equal zero,        0
    assert_equal one_hundred, 100
    assert_equal sixty,       60
    assert_equal one_sixty,   160
    assert_equal impossible,  -60
  end

  def test_corrected_initial_age
    via_good1 = {'Via' => ['HTTP/1.1 test.com'], 'Age' => 100}
    via_good2 = {'Via' => ['1.1 test.com'],      'Age' => 200}
    via_good3 = {'Via' => ['HTTP/1.1'],          'Age' => 300}
    via_good4 = {'Via' => ['1.1'],               'Age' => 400}
    via_bad   = {'Via' => ['HTTP/1.1', '1.0'],   'Age' => 500}
    via_noage = {'Via' => ['1.1']}

    apparent_age = Proc.new { 1000 }

    good1  = CacheRules.helper_corrected_initial_age(via_good1, Proc.new { 100 }, apparent_age).call
    good2  = CacheRules.helper_corrected_initial_age(via_good2, Proc.new { 200 }, apparent_age).call
    good3  = CacheRules.helper_corrected_initial_age(via_good3, Proc.new { 300 }, apparent_age).call
    good4  = CacheRules.helper_corrected_initial_age(via_good4, Proc.new { 400 }, apparent_age).call
    bad    = CacheRules.helper_corrected_initial_age(via_bad,   Proc.new { 500 }, apparent_age).call
    noage  = CacheRules.helper_corrected_initial_age(via_noage, Proc.new { 42 },  apparent_age).call

    assert_kind_of Integer, good1

    assert_equal good1, 100
    assert_equal good2, 200
    assert_equal good3, 300
    assert_equal good4, 400
    assert_equal bad,   1000
    assert_equal noage, 1000
  end

  def test_current_age
    now = @request_headers_new['If-Modified-Since']['timestamp']

    current_age = CacheRules.helper_current_age now, @cached_headers

    assert_equal current_age, 165600
  end

  def test_freshness_lifetime
    cur_time    = Time.now.gmtime.to_i
    current_age = CacheRules.helper_current_age cur_time, @cached_headers
    freshness   = CacheRules.helper_freshness_lifetime.call @cached_headers

    assert_kind_of Array, freshness
    assert_equal freshness[0], 0
    assert_in_delta freshness[1], current_age, 2
  end

  def test_explicit
    s_maxage = CacheRules.helper_explicit({'Cache-Control' => {'s-maxage'=>{'token'=>60}}})
    max_age  = CacheRules.helper_explicit({'Cache-Control' => {'max-age'=>{'token'=>100}}})
    expires  = CacheRules.helper_explicit({'Expires' => {'timestamp'=>1420196565}, 'Date'=> {'timestamp'=>1420196565}})
    noop     = CacheRules.helper_explicit({})

    assert_equal s_maxage, 60
    assert_equal max_age, 100
    assert_equal expires, 0
    assert_nil noop
  end

  def test_heuristic
    now = @request_headers_new['If-Modified-Since']['timestamp']

    last_modified = CacheRules.helper_heuristic now, @cached_headers, 100
    not_public    = CacheRules.helper_heuristic now, @cached_rule2,   100
    too_old       = CacheRules.helper_heuristic now, @cached_headers, 86401
    noop          = CacheRules.helper_heuristic(now, {}, 42)

    assert_equal last_modified, 16560
    assert_equal not_public,    0
    assert_equal too_old,       0
    assert_equal noop,          0
  end

  def test_max_stale
    stale   = CacheRules.helper_max_stale.call @request_headers['Cache-Control'], 0, 0
    fresh   = CacheRules.helper_max_stale.call @request_headers['Cache-Control'], 0, 2000
    noop    = CacheRules.helper_max_stale.call @request_headers_nothing, 0, 0
    notoken = CacheRules.helper_max_stale.call({'max-stale'=>{'token'=>nil}}, 0, 0)

    assert_kind_of TrueClass, stale
    assert_kind_of FalseClass, fresh
    assert_nil noop
    assert_kind_of TrueClass, notoken
  end

  def test_min_fresh
    min     = CacheRules.helper_min_fresh.call({'min-fresh'=>{'token'=>1000}}, 0, 0)
    fresh   = CacheRules.helper_min_fresh.call({'min-fresh'=>{'token'=>"1000"}}, 2000, 0)
    noop    = CacheRules.helper_min_fresh.call @request_headers_nothing, 0, 0

    assert_kind_of FalseClass, min
    assert_kind_of TrueClass,  fresh
    assert_nil noop
  end

  def test_no_cache
    quoted      = CacheRules.helper_no_cache.call @cached_headers
    not_quoted  = CacheRules.helper_no_cache.call({'Cache-Control'=>{'no-cache'=>{'quoted_string'=>""}}})
    noop        = CacheRules.helper_no_cache.call({'Cache-Control'=>{'no-cache'=>nil}})

    assert_kind_of TrueClass, quoted
    assert_kind_of FalseClass, not_quoted
    assert_nil noop
  end

  def test_make_request
    result = CacheRules.helper_make_request 'fake http object', 'fake request object'

    assert_kind_of Proc, result
    assert_equal result.arity, 0
  end

end
