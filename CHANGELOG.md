# Changelog

## 0.1.6 (2014-02-02)

  * Don't rescue ArgumentError on httpdate parse errors

## 0.1.5 (2014-02-02)

  * Closes #3. Returns all cached headers according to RFC 7234 sec4.3.4

## 0.1.4 (2014-02-01)

  * HTTP `Age` header is now returned as a String, but processed as an Integer
