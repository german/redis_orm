Gem::Specification.new do |s|
  s.name = "redis_orm"
  s.version = "0.9"
  s.authors = ["Dmitrii Samoilov"]
  s.date = "2024-07-19"
  s.description = "ORM for Redis (advanced key-value storage) with ActiveRecord API"
  s.email = "germaninthetown@gmail.com"
  s.extra_rdoc_files = ["CHANGELOG", "LICENSE", "README.md", "TODO", "lib/rails/generators/redis_orm/model/model_generator.rb", "lib/rails/generators/redis_orm/model/templates/model.rb.erb", "lib/redis_orm.rb", "lib/redis_orm/active_model_behavior.rb", "lib/redis_orm/associations/belongs_to.rb", "lib/redis_orm/associations/has_many.rb", "lib/redis_orm/associations/has_many_helper.rb", "lib/redis_orm/associations/has_many_proxy.rb", "lib/redis_orm/associations/has_one.rb", "lib/redis_orm/redis_orm.rb", "lib/redis_orm/utils.rb"]
  s.license = 'MIT'
  s.homepage = "https://github.com/german/redis_orm"
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Redis_orm", "--main", "README.md"]
  s.require_paths = ["lib"]
  s.rubyforge_project = "redis_orm"
  s.summary = "ORM for Redis (advanced key-value storage) with ActiveRecord API"

  s.add_runtime_dependency(%q<activesupport>, ["> 5.1"])
  s.add_runtime_dependency(%q<activemodel>, ["> 5.1"])
  s.add_runtime_dependency(%q<redis>, [">= 4.2.5"])
  s.add_runtime_dependency(%q<uuid>, [">= 2.3.2"])
  s.add_development_dependency(%q<rspec>, [">= 3.10"])
  s.add_development_dependency(%q<rspec-rails>, [">= 4"])
  s.add_development_dependency(%q<ammeter>, [">= 1.1"])
end
