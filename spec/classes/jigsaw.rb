class Jigsaw < RedisOrm::Base
  property :title, String
  belongs_to :user
end
