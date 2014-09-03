# for second test
class Person < RedisOrm::Base
  property :name, String
  
  belongs_to :location, :polymorphic => true
end
