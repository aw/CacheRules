# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2014-2015 Alexander Williams, Unscramble <license@unscramble.jp>

module CacheRules
  extend self

  # HTTP Header Actions

  def action_revalidate(result)
    result[:value]
  end

  # Generate an age equal to the current cached entry's age
  # source: https://tools.ietf.org/html/rfc7234#section-4
  def action_add_age(result)
    current_age = helper_current_age Time.now.gmtime.to_i, result[:cached]

    {'Age' => current_age}
  end

  def action_add_x_cache(result)
    {'Cache-Lookup' => result[:value]}
  end

  def action_add_warning(result)
    {'Warning' => result[:value]}
  end

  def action_add_status(result)
    result[:value]
  end

  def action_return_body(result)
    result[:value]
  end

end
