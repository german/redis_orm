class Profile < RedisOrm::Base
  property :title, String
  property :name, String

  belongs_to :user
  has_one :location
  has_one :city
end
