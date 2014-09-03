class Message < RedisOrm::Base
  property :text, String
  has_one :message, :as => :replay_to
end
