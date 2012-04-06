class User < RedisOrm::Base
  property :name, String   
  property :first_name, String
  property :last_name, String
  property :karma, Integer, :default => 1000
  property :age, Integer
  property :wage, Float
  property :male, RedisOrm::Boolean
  property :created_at, Time
  property :modified_at, Time
  property :gender, RedisOrm::Boolean, :default => true
  property :moderator, RedisOrm::Boolean, :default => false
  property :moderated_area, String, :default => "messages"
  
  index :moderator
  index [:moderator, :moderated_area]
  index :age
  index :name 
  index :first_name
  index :last_name
  index [:first_name, :last_name]

  has_one :profile
  has_many :comments
  has_many :users, :as => :friends
  has_one :photo, :dependent => :destroy

  after_create :store_in_rating
  after_destroy :after_destroy_callback

  def store_in_rating
    $redis.zadd "users:sorted_by_rating", 0.0, self.id
  end

  def after_destroy_callback
    self.comments.map{|c| c.destroy}
  end
end
