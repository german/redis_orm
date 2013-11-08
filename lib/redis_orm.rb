# -*- encoding: utf-8 -*-

require 'active_model'
require 'redis'
require 'uuid'
require File.join(File.dirname(File.expand_path(__FILE__)), 'redis_orm', 'active_model_behavior')

require File.join(File.dirname(File.expand_path(__FILE__)), 'redis_orm', 'associations', 'belongs_to')

require File.join(File.dirname(File.expand_path(__FILE__)), 'redis_orm', 'associations', 'has_many_helper')

require File.join(File.dirname(File.expand_path(__FILE__)), 'redis_orm', 'associations', 'has_many_proxy')
require File.join(File.dirname(File.expand_path(__FILE__)), 'redis_orm', 'associations', 'has_many')
require File.join(File.dirname(File.expand_path(__FILE__)), 'redis_orm', 'associations', 'has_one')

require File.join(File.dirname(File.expand_path(__FILE__)), 'redis_orm', 'utils')

class String
  def i18n_key
    self.to_s.tableize
  end

  def human
    self.to_s.humanize
  end
end

require File.join(File.dirname(File.expand_path(__FILE__)), 'redis_orm', 'redis_orm')

module RedisOrm
  extend self

  attr_accessor :redis
  @@redis = Redis.new

  def self.redis=(redis)
    @@redis = redis
  end

  def self.redis
    @@redis
  end
end
