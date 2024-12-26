class SortableUser < RedisOrm::Base
  property :name, String, sortable: true
  property :age, Integer, sortable: true, default: 26.0
  property :wage, Float, sortable: true, default: 20_000
  property :address, String, default: "Singa_poor"
  
  property :test_type_cast, RedisOrm::Boolean, default: false

  index :age
  index :name
end
