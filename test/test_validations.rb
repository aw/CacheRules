class TestValidations < MiniTest::Test

  def setup
    cache_control   = {"max-stale"=>{"token"=>9999999, "quoted_string"=>nil},"only-if-cached"=>{"token"=>nil, "quoted_string"=>nil}}
    if_modified     = {"httpdate"=>"Thu, 01 Jan 2015 07:03:42 GMT", "timestamp"=>1420095822}
    date            = {"httpdate"=>"Fri, 02 Jan 2015 11:03:45 GMT", "timestamp"=>1420196625}
    next_date       = {"httpdate"=>"Sat, 03 Jan 2037 07:03:45 GMT", "timestamp"=>2114579025}
    if_modified_new = {"httpdate"=>"Sun, 04 Jan 2015 09:03:45 GMT", "timestamp"=>1420362225}
    cache_min_fresh = {"min-fresh"=>{"token"=>9999999, "quoted_string"=>nil},"only-if-cached"=>{"token"=>nil, "quoted_string"=>nil}}

    @headers = {
      :request => {
        "If-Modified-Since" => if_modified,
        "Cache-Control" => cache_control,
        "If-None-Match" => ["\"myetag\"", "\"validEtag\""]
      },
      :cached => {
        "Date"              => date,
        "Cache-Control"     => {
          "public"          => {"token"=>nil, "quoted_string"=>nil},
          "max-stale"       => {"token"=>"1000", "quoted_string"=>nil}
        },
        "Last-Modified"     => {"httpdate"=>"Thu, 01 Jan 2015 07:03:42 GMT", "timestamp"=>1420095822},
        "ETag"              => "\"validEtag\"",
        "X-Cache-Req-Date"  => date,
        "X-Cache-Res-Date"  => date
      }
    }
    @headers_stale = {
      :request => {
        "If-Modified-Since" => if_modified,
        "Cache-Control" => cache_control
      },
      :cached => {
        "Date"              => {"httpdate"=>"Tue, 28 Apr 2015 09:26:57 GMT", "timestamp"=>1430213217},
        "Cache-Control"     => {
          "public"          => {"token"=>nil, "quoted_string"=>nil},
          "max-stale"       => {"token"=>"100", "quoted_string"=>nil}
        },
        "Last-Modified"     => {"httpdate"=>"Tue, 28 Apr 2015 09:26:57 GMT", "timestamp"=>1430213217},
        "X-Cache-Req-Date"  => {"httpdate"=>"Tue, 28 Apr 2015 09:26:57 GMT", "timestamp"=>1430213217},
        "X-Cache-Res-Date"  => {"httpdate"=>"Tue, 28 Apr 2015 09:26:57 GMT", "timestamp"=>1430213217}
      }
    }
    @headers_noetag = {
      :request => {
        "If-None-Match" => ["\"myetag\""]
      },
      :cached => {
        "Date"              => date,
        "Cache-Control"     => {
          "public"          => {"token"=>nil, "quoted_string"=>nil},
          "no-cache"        => {"token"=>nil, "quoted_string"=>"Cookie"},
          "proxy-revalidate" => {"token"=>nil, "quoted_string"=>nil}
        },
        "ETag"              => "\"validEtag\"",
        "X-Cache-Req-Date"  => date,
        "X-Cache-Res-Date"  => date
      }
    }
    @no_headers = {
      :request => {},
      :cached => {}
    }
    @headers_nothing = {
      :request => {"If-None-Match" => ["\"myetag\""] },
      :cached => {
        "Date"              => next_date,
        "X-Cache-Req-Date"  => next_date,
        "X-Cache-Res-Date"  => next_date,
        "Cache-Control"     => {
          "must-revalidate" => {"token"=>nil, "quoted_string"=>nil}
        }
      }
    }
    @cached_rule2 = {
      :request => {
        "If-Modified-Since" => if_modified_new,
        "Cache-Control" => cache_min_fresh
      },
      :cached => {
        "Date"              => next_date,
        "X-Cache-Req-Date"  => next_date,
        "X-Cache-Res-Date"  => next_date
      }
    }
  end

  def test_to_bit
    one   = CacheRules.to_bit { true }
    zero  = CacheRules.to_bit { false }

    assert_equal one,  1
    assert_equal zero, 0
  end

  def test_cached
    one   = CacheRules.validate_cached? @headers
    zero  = CacheRules.validate_cached? @no_headers

    assert_equal one,  1
    assert_equal zero, 0
  end

  def test_precond_match
    guard     = CacheRules.validate_precond_match? @no_headers
    etag_one  = CacheRules.validate_precond_match? @headers
    etag_zero = CacheRules.validate_precond_match? @headers_noetag
    mod_true  = CacheRules.validate_precond_match? @cached_rule2
    mod_false = CacheRules.validate_precond_match? @headers_nothing

    assert_equal guard, 0
    assert_equal etag_one, 1
    assert_equal etag_zero, 0
    assert_equal mod_true, 1
    assert_equal mod_false, 0
  end

  def test_expired
    guard     = CacheRules.validate_expired? @no_headers
    stale     = CacheRules.validate_expired? @headers
    fresh     = CacheRules.validate_expired? @headers_nothing

    assert_equal guard, 0
    assert_equal stale, 1
    assert_equal fresh, 0
  end

  def test_only_if_cached
    one   = CacheRules.validate_only_if_cached? @headers
    zero  = CacheRules.validate_only_if_cached? @headers_noetag

    assert_equal one,  1
    assert_equal zero, 0
  end

  def test_allow_stale
    guard1    = CacheRules.validate_allow_stale? @no_headers
    guard2    = CacheRules.validate_allow_stale? @headers_noetag
    max_stale = CacheRules.validate_allow_stale? @headers_stale
    min_fresh = CacheRules.validate_allow_stale? @cached_rule2
    nothing   = CacheRules.validate_allow_stale? @headers_nothing

    assert_equal guard1,    0
    assert_equal guard2,    0
    assert_equal max_stale, 1
    assert_equal min_fresh, 1
    assert_equal nothing,   0
  end

  def test_must_revalidate
    guard           = CacheRules.validate_must_revalidate? @no_headers
    must_revalidate = CacheRules.validate_must_revalidate? @headers_nothing
    proxy_revalidate= CacheRules.validate_must_revalidate? @headers_noetag
    nothing         = CacheRules.validate_must_revalidate? @headers

    assert_equal guard, 1
    assert_equal must_revalidate, 1
    assert_equal proxy_revalidate, 1
    assert_equal nothing, 0
  end

  def test_no_cache
    headers1 = {
      :request => {'Cache-Control' => {'no-cache'=>{'token'=>nil}}},
      :cached => {'Cache-Control' => {}}
    }
    headers2 = {
      :request => {},
      :cached => {'Cache-Control' => {'no-cache'=>{'quoted_string'=>"Cookie"}}}
    }
    headers2_nil = {
      :request => {},
      :cached => {'Cache-Control' => {'no-cache'=>{'quoted_string'=>nil}}}
    }
    headers3 = {
      :request => {},
      :cached => {'Cache-Control' => {'s-maxage'=>{'token'=>"0"}}}
    }
    headers4 = {
      :request => {},
      :cached => {'Cache-Control' => {'max-age'=>{'token'=>0}}}
    }
    headers5 = {
      :request => {'Pragma' => {'no-cache'=>{'token'=>nil}}},
      :cached => {'Cache-Control' => {}}
    }

    guard     = CacheRules.validate_no_cache? @no_headers
    no_cache1 = CacheRules.validate_no_cache? headers1
    no_cache2 = CacheRules.validate_no_cache? headers2
    no_cache3 = CacheRules.validate_no_cache? headers2_nil
    s_maxage  = CacheRules.validate_no_cache? headers3
    maxage    = CacheRules.validate_no_cache? headers4
    pragma    = CacheRules.validate_no_cache? headers5
    nothing   = CacheRules.validate_no_cache? @headers

    assert_equal guard,     1
    assert_equal no_cache1, 1
    assert_equal no_cache2, 1
    assert_equal no_cache3, 1
    assert_equal s_maxage,  1
    assert_equal maxage,    1
    assert_equal pragma,    1
    assert_equal nothing,   0
  end

  def test_is_error
    not_error1 = CacheRules.validate_is_error?({:response => {'Status'=>499}})
    not_error2 = CacheRules.validate_is_error?({:response => {'Status'=>600}})
    is_error1  = CacheRules.validate_is_error?({:response => {'Status'=>500}})
    is_error2  = CacheRules.validate_is_error?({:response => {'Status'=>550}})
    is_error3  = CacheRules.validate_is_error?({:response => {'Status'=>599}})

    assert_equal not_error1, 0
    assert_equal not_error2, 0
    assert_equal is_error1,  1
    assert_equal is_error2,  1
    assert_equal is_error3,  1
  end

  def test_validator_match
    match   = CacheRules.validate_validator_match?({:request => {'If-None-Match'=>["\"myetag\""]}, :response => {'ETag'=>"\"myetag\""}})
    nomatch = CacheRules.validate_validator_match?({:request => {'If-None-Match'=>["\"myetag\""]}, :response => {}})

    assert_equal match,   1
    assert_equal nomatch, 0
  end

end
