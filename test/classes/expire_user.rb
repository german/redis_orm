class ExpireUser < RedisOrm::Base
  property :name, String

  expire 10.minutes.from_now
end
