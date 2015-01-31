require 'coveralls'
require 'fakeweb'
require 'simplecov'

SimpleCov.start do
  add_filter '/test/'
  add_filter '.bundle'
  minimum_coverage 100
end

require './lib/cache_rules'
require 'minitest/autorun'
require 'minitest/unit'
require 'minitest/reporters'

Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]

Coveralls.wear!
