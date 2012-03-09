class Article < RedisOrm::Base
  property :title, String
  has_many :comments
  has_many :categories
end
