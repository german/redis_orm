class ArticleWithComments < RedisOrm::Base
  property :title, String
  property :comments, Array

  has_many :categories
end
