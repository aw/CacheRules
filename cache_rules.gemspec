#!/usr/bin/env gem build
# encoding: utf-8

require "base64"
require 'date'

Gem::Specification.new do |s|
  s.name        = 'cache_rules'
  s.version     = '0.4.1'

  s.date        = Date.today.to_s

  s.summary     = "CacheRules validates requests and responses for cached HTTP data based on RFCs 7230-7235"
  s.description = "#{s.summary}. The goal is to facilitate implementation of well-behaved caching solutions which adhere to RFC standards."

  s.author      = 'Alexander Williams'
  s.email       = Base64.decode64("YXdpbGxpYW1zQGFsZXh3aWxsaWFtcy5jYQ==\n")

  s.homepage    = 'https://github.com/aw/CacheRules'

  s.require_paths = ["lib"]
  s.files       = `git ls-files`.split("\n")

  # Tests
  s.add_development_dependency "fakeweb",            '~> 1.3'
  s.add_development_dependency 'minitest',           '~> 5.5.0'
  s.add_development_dependency 'minitest-reporters', '~> 1.0.0'
  s.add_development_dependency 'simplecov'

  s.licenses = ['MPL-2.0']
  s.required_ruby_version = ::Gem::Requirement.new(">= 1.9")
end
