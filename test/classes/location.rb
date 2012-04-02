class Location < RedisOrm::Base
  property :coordinates, String
  
  has_many :profiles
end
