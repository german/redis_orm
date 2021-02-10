class Album < RedisOrm::Base
  property :title, String

  has_one :photo, as: :front_photo
  has_many :photos, dependent: :destroy
end
