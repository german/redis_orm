require 'active_model'
require 'redis'
require 'uuid'

require_relative 'redis_orm/active_model_behavior'
require_relative 'redis_orm/associations/belongs_to'
require_relative 'redis_orm/associations/has_many_helper'
require_relative 'redis_orm/associations/has_many_proxy'
require_relative 'redis_orm/associations/has_many'
require_relative 'redis_orm/associations/has_one'
require_relative 'redis_orm/utils'

class String
  def i18n_key
    self.to_s.tableize
  end

  def human
    self.to_s.humanize
  end
end

require_relative 'redis_orm/redis_orm'
