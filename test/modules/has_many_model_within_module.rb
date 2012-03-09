module HasManyModelWithinModule
  class SpecialComment < RedisOrm::Base
    property :body, String, :default => "test"
    belongs_to :brochure, :as => :book
  end

  class Brochure < RedisOrm::Base
    property :title, String
    has_many :special_comments
  end
end
