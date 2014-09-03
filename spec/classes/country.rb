class Country < RedisOrm::Base
  property :name, String

  has_many :people
end
