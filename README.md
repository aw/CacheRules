## What is CacheRules

_CacheRules_ is a well-behaved HTTP caching library aimed at being [RFC 7234](https://tools.ietf.org/html/rfc7234) compliant.

This library does **not actually _cache_ anything**, and it is **not a _proxy_**.
It validates HTTP headers and returns the appropriate response to determine
if a request can be served from the cache.

It is up to the HTTP Cache implementation to store the cached results
and serve responses from the cache if necessary.

[![Build Status](https://travis-ci.org/aw/CacheRules.svg?branch=master)](https://travis-ci.org/aw/CacheRules) [![Coverage Status](https://coveralls.io/repos/aw/CacheRules/badge.svg?branch=master)](https://coveralls.io/r/aw/CacheRules?branch=master) [![Gem Version](https://badge.fury.io/rb/cache_rules.svg)](http://badge.fury.io/rb/cache_rules)

## Getting started

Add this line to your Gemfile: `gem 'cache_rules'`

  or

Install with: `gem install cache_rules`

## Usage

There is only 1 _public API call_ when using this library: `validate()`.

```ruby
require 'cache_rules'

url     = 'https://status.rubygems.org'
request = {'Version' => 'HTTP/1.1'}
cached  = {}

CacheRules.validate url, request, cached

=>  {:body=>nil, :code=>307, :headers=>{"Cache-Lookup"=>"MISS", "Location"=>"https://status.rubygems.org"}}
```

The `request` headers must be a Ruby Hash or Array of 2-element Arrays.
The `cached` headers must already have been normalized by this caching library.

## Decision tables

There are two decision tables to help figure out how to process each type of
HTTP Caching request.

### Request/Cache Table

![cached](https://cloud.githubusercontent.com/assets/153401/7445031/9d64eb2c-f190-11e4-8938-44a443f9bec3.png)

### Revalidation Table

![revalidation](https://cloud.githubusercontent.com/assets/153401/7445040/09c747ba-f191-11e4-8b9c-a8b26709fb99.png)

## RFC compliance

This HTTP Caching library aims to be RFC 7230-7235 compliant. It is a best
effort attempt to correctly interpret these documents. Some errors may exist,
so please [notify me](https://github.com/aw/CacheRules/issues/new) if something isn't processed correctly according to the RFCs.

### Feature list

  * Normalizing header names and field values (ex: `Last-Modified`)
  * Ensuring date fields are correctly formatted (ex: `Fri, 31 Dec 1999 23:59:59 GMT`)
  * Merging duplicate header fields
  * Interop with HTTP/1.0 clients (ex: `Pragma: no-cache`)
  * Weak entity-tag matching (ex: `If-None-Match: "W/abc123"`)
  * Last modified date matching (ex: `If-Modified-Since: Thu, 01 Jan 2015 07:03:45 GMT`)
  * Various header validation including Cache-Control headers
  * Cache-Control directives with quoted strings (ex: `no-cache="Cookie"`)
  * Removing non-cacheable headers (ex: `Authorization`)
  * Correctly calculating freshness and current age of cached responses
  * Explicit and Heuristic freshness calculation
  * Returning 110 and 111 Warning headers when serving stale responses
  * Revalidating expired responses with the origin server (using HEAD)
  * Returning the correct status code based on validation/revalidation results
  * Lots more little things sprinkled throughout the RFCs...
  * Written in purely functional Ruby (mostly) with 100% unit/integration test coverage

## Custom headers

Custom headers are generated to help with testing and compliance validation.

These are somewhat based on [CloudFlare's](https://support.cloudflare.com/hc/en-us/articles/200168266-What-do-the-various-CloudFlare-cache-responses-HIT-Expired-etc-mean-) cache headers:

  * `Cache-Lookup: HIT`: resource is in cache and still valid. Serving from the cache.
  * `Cache-Lookup: MISS`: resource is not in cache. Redirecting to the origin server.
  * `Cache-Lookup: EXPIRED`: resource is in cache, but expired. Redirecting to the origin server or serving an error message.
  * `Cache-Lookup: STALE`: resource is in cache and expired, but the origin server wasn't contacted successfully to revalidate the request. Serving stale response from the cache.
  * `Cache-Lookup: REVALIDATED`: resource is in cache, was expired, but was revalidated successfully at the origin server. Serving from the cache.

## Tests

To run the tests, type:

  `bundle exec rake test`

## TODO

  * Validation of `s-maxage` [response header](https://tools.ietf.org/html/rfc7234#section-5.2.2.9)
  * Handling `Vary` header and different representations for the same resource
  * Handling `206 (Partial)` and `Range` headers for resuming downloads
  * Handling `Cache-Control: private` headers
  * Caching other _cacheable_ responses such as [404 and 501](https://tools.ietf.org/html/rfc7231#section-6.1)

## What is C.R.E.A.M. ?

C.R.E.A.M. is an influencial lyrical masterpiece from the 90s performed by the [Wu-Tang Clan](https://www.youtube.com/watch?v=PBwAxmrE194)

It's also the premise of this [troll video](http://cacheruleseverythingaround.me/)

## Further reading

Some useful articles explaining HTTP Caching:

  * [Caching is hard, draw me a picture](http://www.bizcoder.com/caching-is-hard-draw-me-a-picture)
  * [A Beginner's Guide to HTTP Cache Headers](http://www.mobify.com/blog/beginners-guide-to-http-cache-headers/)

## LICENSE

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at [http://mozilla.org/MPL/2.0/](http://mozilla.org/MPL/2.0/).

Copyright (c) 2014-2015 Alexander Williams, Unscramble
