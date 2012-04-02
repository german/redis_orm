class UuidDefaultUser < RedisOrm::Base
  use_uuid_as_id
  
  property :name, String, :default => "german"
  property :age, Integer, :default => 26
  property :wage, Float, :default => 256.25
  property :male, RedisOrm::Boolean, :default => true
  property :admin, RedisOrm::Boolean, :default => false
  
  property :created_at, Time
  property :modified_at, Time
end
