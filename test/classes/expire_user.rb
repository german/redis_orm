class ExpireUser < RedisOrm::Base
  property :name, String

  expire 10.minutes.from_now
  
  has_many :article
  has_one :profile
end
