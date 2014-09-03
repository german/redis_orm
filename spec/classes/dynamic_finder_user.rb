class DynamicFinderUser < RedisOrm::Base
  property :first_name, String
  property :last_name, String

  index :first_name, :unique => true
  index :last_name,  :unique => true
  index [:first_name, :last_name], :unique => false
end
