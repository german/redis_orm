class Note < RedisOrm::Base
  property :body, :string, default: "made by redis_orm"
  
  belongs_to :user, as: :owner, index: true
end