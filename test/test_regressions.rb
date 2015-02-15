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
end
