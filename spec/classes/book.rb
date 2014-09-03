class Book < RedisOrm::Base
  property :price, Integer, :default => 0 # in cents
  property :title, String
  
  has_one :catalog_item
end
