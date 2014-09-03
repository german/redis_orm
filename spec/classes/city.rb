class City < RedisOrm::Base
  property :name, String
  property :name, String

  has_many :people
  has_many :profiles
end
