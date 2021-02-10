class ArticleWithComments < RedisOrm::Base
  property :title, String
  property :comments, Array

  property :rates, Hash, default: {"1": 0, "2": 0, "3": 0, "4": 0, "5": 0}
  
  has_many :categories
end
