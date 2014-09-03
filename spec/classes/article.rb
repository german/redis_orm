class Article < RedisOrm::Base
  property :title, String
  property :karma, Integer

  has_many :comments
  has_many :categories
end
