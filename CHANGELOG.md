# Changelog

## 0.1.10 (2015-04-20)

  * Remove gemspec post_install message

## 0.1.9 (2015-04-08)

  * Add regression tests for issue #5
  * Update Gemfile.lock / dependencies
  * Fix dates in this CHANGELOG

## 0.1.8 (2015-02-09)

  * Add tests to ensure URLs with query parameters are maintained

## 0.1.7 (2015-02-02)

  * Refactor and simplify `revalidate_response()` method

## 0.1.6 (2015-02-02)

  * Don't rescue ArgumentError on httpdate parse errors

## 0.1.5 (2015-02-02)

  * Closes #3. Returns all cached headers according to RFC 7234 sec4.3.4

## 0.1.4 (2015-02-01)

  * HTTP `Age` header is now returned as a String, but processed as an Integer
