class ExpireUserWithPredicate < RedisOrm::Base
  property :name, String
  property :persist, RedisOrm::Boolean, :default => false

  expire 10.minutes.from_now, :if => Proc.new {|r| !r.persist?}

  has_many :articles
  has_one :profile
  
  def persist?
    !!self.persist
  end
end
