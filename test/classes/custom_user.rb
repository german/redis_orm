class CustomUser < RedisOrm::Base
  property :first_name, String
  property :last_name, String

  index :first_name, :unique => false
  index :last_name,  :unique => false
  index [:first_name, :last_name], :unique => true
end
