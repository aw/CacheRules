class TestRegressions < MiniTest::Test

  #
  # Bugfix tests to ensure we don't allow regressions
  #
  # https://github.com/aw/CacheRules/issues

  def setup
    @cached_headers = {
      :cached => {
        "Date"              => {"httpdate"=>"Thu, 01 Jan 2015 07:03:45 GMT", "timestamp"=>1420095825},
        "Cache-Control"     => {
          "public"          => {"token"=>nil, "quoted_string"=>nil}
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
end
