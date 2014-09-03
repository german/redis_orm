class OmniUser < RedisOrm::Base
  property :email, String
  property :uid, Integer

  index :email, :case_insensitive => true
  index :uid
  index [:email, :uid], :case_insensitive => true
end
