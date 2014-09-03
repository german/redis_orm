class Profile < RedisOrm::Base
  property :title, String
  property :name, String

  belongs_to :user
  belongs_to :expire_user
  has_one :location
  has_one :city
end
