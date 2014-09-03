class CutoutAggregator < RedisOrm::Base
  property :modified_at, Time

  property :revision, Integer, :default => 0
end
