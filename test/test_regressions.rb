class TestRegressions < MiniTest::Test

  #
  # Bugfix tests to ensure we don't allow regressions
  #
  # https://github.com/aw/CacheRules/issues

  def setup
    @cached_headers = {
      :cached => {
        "Age"               => "99999",
        "Date"              => {"httpdate"=>"Thu, 01 Jan 2015 07:03:45 GMT", "timestamp"=>1420095825},
        "Cache-Control"     => {
          "public"          => {"token"=>nil, "quoted_string"=>nil},
          "max-age"         => {"token"=>"10", "quoted_string"=>nil}
        },
        "X-Cache-Req-Date"  => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625},
        "X-Cache-Res-Date"  => {"httpdate"=>"Sat, 03 Jan 2015 07:03:45 GMT", "timestamp"=>1420268625}
      }
    }
  end

  # https://github.com/aw/CacheRules/issues/5
  def test_bugfix_5_age_header_string_integer
    age_string  = CacheRules.action_add_age @cached_headers
    age_integer = CacheRules.helper_corrected_initial_age({}, Proc.new { 100 }, Proc.new { 99 }).call

    assert_kind_of String,  age_string['Age']
    assert_kind_of Integer, age_integer
  end

  # https://github.com/aw/CacheRules/issues/7
  def test_bugfix_7_invalid_validation_of_max_stale
    request = {"Host"=>"test.url"}

    no_max_stale = CacheRules.helper_max_stale.call request, 0, 0

    assert_kind_of TrueClass, no_max_stale
  end

  # https://github.com/aw/CacheRules/issues/8
  def test_bugfix_8_errors_caused_by_empty_http_headers
    isnil   = CacheRules.clean.call({'Content-Type'=>nil})
    isempty = CacheRules.clean.call({'Content-Type'=>''})

    assert_equal isnil,   []
    assert_equal isempty, []
  end

  # https://github.com/aw/CacheRules/issues/10
  def test_bugfix_10_request_header_max_age_is_checked
    request_maxage = CacheRules.validate_no_cache?({
      :cached   => @cached_headers[:cached],
      :request  => {"Cache-Control" => {"max-age" => {"token"=>0, "quoted_string"=>nil} } }
    })
    current = CacheRules.validate_no_cache?({
      :cached   => @cached_headers[:cached],
      :request  => {"Cache-Control" => {"max-age" => {"token"=>1000, "quoted_string"=>nil} } }
    })
    cached_max_age = CacheRules.validate_expired?({
      :cached   => @cached_headers[:cached],
      :request  => {}
    })

    assert_equal 1, request_maxage
    assert_equal 1, current
    assert_equal 1, cached_max_age
  end

  # https://github.com/aw/CacheRules/issues/13
  def test_bugfix_13_revalidate_without_preconditions
    if_none_match = CacheRules.helper_has_preconditions.({'If-None-Match'=>'*'},{})
    etag          = CacheRules.helper_has_preconditions.({}, {'ETag'=>["abcdefg"]})
    last_modified = CacheRules.helper_has_preconditions.({}, {'Last-Modified'=>{"httpdate"=>"Fri, 02 Jan 2015 11:03:45 GMT", "timestamp"=>1420196625}})
    empty         = CacheRules.helper_has_preconditions.({}, {})
    no_precond    = CacheRules.revalidate_response('ftp://test.url/test1', {}, {})

    assert_equal "*", if_none_match
    assert_equal ["abcdefg"], etag
    assert_equal({"httpdate"=>"Fri, 02 Jan 2015 11:03:45 GMT", "timestamp"=>1420196625}, last_modified)
    assert_nil empty

    assert_equal no_precond[:code], 504
    assert_equal no_precond[:body], 'Gateway Timeout'
    assert_nil   no_precond[:error]
  end

end
