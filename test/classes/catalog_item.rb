class CatalogItem < RedisOrm::Base
  property :title, String

  belongs_to :resource, :polymorphic => true
end
