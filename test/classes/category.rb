class Category < RedisOrm::Base
  property :name, String
  property :title, String

  has_many :articles
  has_many :photos, :dependent => :nullify
end
