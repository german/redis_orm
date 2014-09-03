class UuidTimeStamp < RedisOrm::Base
  use_uuid_as_id

  timestamps
end
