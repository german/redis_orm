module BelongsToModelWithinModule
  class Reply < RedisOrm::Base
    property :body, String, :default => "test"
    belongs_to :article, :as => :essay
  end
end
