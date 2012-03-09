class Profile < RedisOrm::Base
  property :title, String
  has_one :city
end
