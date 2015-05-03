class TestTables < MiniTest::Test

  def setup
    @request_map  = {"0000000"=>0, "0000001"=>0, "0000010"=>1, "0000011"=>1, "0000100"=>0, "0000101"=>0, "0000110"=>1, "0000111"=>1, "0001000"=>0, "0001001"=>0, "0001010"=>1, "0001011"=>1, "0001100"=>0, "0001101"=>0, "0001110"=>1, "0001111"=>1, "0010000"=>0, "0010001"=>0, "0010010"=>1, "0010011"=>1, "0010100"=>0, "0010101"=>0, "0010110"=>1, "0010111"=>1, "0011000"=>0, "0011001"=>0, "0011010"=>1, "0011011"=>1, "0011100"=>0, "0011101"=>0, "0011110"=>1, "0011111"=>1, "0100000"=>0, "0100001"=>0, "0100010"=>1, "0100011"=>1, "0100100"=>0, "0100101"=>0, "0100110"=>1, "0100111"=>1, "0101000"=>0, "0101001"=>0, "0101010"=>1, "0101011"=>1, "0101100"=>0, "0101101"=>0, "0101110"=>1, "0101111"=>1, "0110000"=>0, "0110001"=>0, "0110010"=>1, "0110011"=>1, "0110100"=>0, "0110101"=>0, "0110110"=>1, "0110111"=>1, "0111000"=>0, "0111001"=>0, "0111010"=>1, "0111011"=>1, "0111100"=>0, "0111101"=>0, "0111110"=>1, "0111111"=>1, "1000000"=>2, "1000001"=>2, "1000010"=>2, "1000011"=>2, "1000100"=>6, "1000101"=>4, "1000110"=>6, "1000111"=>4, "1001000"=>3, "1001001"=>3, "1001010"=>3, "1001011"=>3, "1001100"=>6, "1001101"=>5, "1001110"=>6, "1001111"=>5, "1010000"=>8, "1010001"=>8, "1010010"=>8, "1010011"=>8, "1010100"=>8, "1010101"=>8, "1010110"=>8, "1010111"=>8, "1011000"=>8, "1011001"=>8, "1011010"=>8, "1011011"=>8, "1011100"=>8, "1011101"=>8, "1011110"=>8, "1011111"=>8, "1100000"=>2, "1100001"=>2, "1100010"=>2, "1100011"=>2, "1100100"=>7, "1100101"=>7, "1100110"=>7, "1100111"=>7, "1101000"=>3, "1101001"=>3, "1101010"=>3, "1101011"=>3, "1101100"=>7, "1101101"=>7, "1101110"=>7, "1101111"=>7, "1110000"=>8, "1110001"=>8, "1110010"=>8, "1110011"=>8, "1110100"=>8, "1110101"=>8, "1110110"=>8, "1110111"=>8, "1111000"=>8, "1111001"=>8, "1111010"=>8, "1111011"=>8, "1111100"=>8, "1111101"=>8, "1111110"=>8, "1111111"=>8}
    @response_map = {"000"=>0, "001"=>1, "010"=>0, "011"=>1, "100"=>2, "101"=>2, "110"=>3, "111"=>4}
  end

  def test_x_value
    assert_kind_of NilClass, CacheRules::X

    assert_nil CacheRules::X
  end

  def test_request_table
    assert_kind_of Hash, CacheRules::REQUEST_TABLE

    assert_includes CacheRules::REQUEST_TABLE, :conditions
    assert_includes CacheRules::REQUEST_TABLE, :actions

    assert_equal CacheRules::REQUEST_TABLE[:conditions].length, 7
    assert_equal CacheRules::REQUEST_TABLE[:actions].length, 6

    conditions = CacheRules::REQUEST_TABLE[:conditions].keys
    actions    = CacheRules::REQUEST_TABLE[:actions].keys
    assert_equal conditions, %w(cached must_revalidate no_cache precond_match expired only_if_cached allow_stale)
    assert_equal actions,    %w(revalidate add_age add_x_cache add_warning add_status return_body)
  end

  def test_response_table
    assert_kind_of Hash, CacheRules::RESPONSE_TABLE

    assert_includes CacheRules::RESPONSE_TABLE, :conditions
    assert_includes CacheRules::RESPONSE_TABLE, :actions

    assert_equal CacheRules::RESPONSE_TABLE[:conditions].length, 3
    assert_equal CacheRules::RESPONSE_TABLE[:actions].length, 6

    conditions = CacheRules::RESPONSE_TABLE[:conditions].keys
    actions    = CacheRules::RESPONSE_TABLE[:actions].keys
    assert_equal conditions, %w(is_error allow_stale validator_match)
    assert_equal actions,    %w(revalidate add_age add_x_cache add_warning add_status return_body)
  end

  def test_request_map_is_correct
    assert_kind_of Hash, CacheRules::REQUEST_MAP

    assert_equal CacheRules::REQUEST_MAP.length, 128
    assert_equal CacheRules::REQUEST_MAP, @request_map

    assert_equal CacheRules::REQUEST_MAP["0000000"], 0
    assert_equal CacheRules::REQUEST_MAP["0000010"], 1
    assert_equal CacheRules::REQUEST_MAP["1000000"], 2
    assert_equal CacheRules::REQUEST_MAP["1001000"], 3
    assert_equal CacheRules::REQUEST_MAP["1000101"], 4
    assert_equal CacheRules::REQUEST_MAP["1001101"], 5
    assert_equal CacheRules::REQUEST_MAP["1000100"], 6
    assert_equal CacheRules::REQUEST_MAP["1100100"], 7
    assert_equal CacheRules::REQUEST_MAP["1010000"], 8
  end

  def test_response_map_is_correct
    assert_kind_of Hash, CacheRules::RESPONSE_MAP

    assert_equal CacheRules::RESPONSE_MAP.length, 8
    assert_equal CacheRules::RESPONSE_MAP, @response_map

    assert_equal CacheRules::RESPONSE_MAP["000"], 0
    assert_equal CacheRules::RESPONSE_MAP["001"], 1
    assert_equal CacheRules::RESPONSE_MAP["100"], 2
    assert_equal CacheRules::RESPONSE_MAP["110"], 3
    assert_equal CacheRules::RESPONSE_MAP["111"], 4
  end

end
