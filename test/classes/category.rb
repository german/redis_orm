class Category < RedisOrm::Base
  property :name, String
  has_many :articles
end
