class UuidUser < RedisOrm::Base
  use_uuid_as_id
  
  property :name, String
  property :age, Integer
  property :wage, Float
  property :male, RedisOrm::Boolean

  property :created_at, Time
  property :modified_at, Time
  
  has_many :users, :as => :friends
end
