Gem::Specification.new do |s|
  s.name = "redis_orm"
  s.version = "1.0"
  s.authors = ["Dmitrii Samoilov"]
  s.date = "2021-02-07"
  s.description = "ORM for Redis (advanced key-value storage) with ActiveRecord API"
  s.email = "germaninthetown@gmail.com"
  s.extra_rdoc_files = ["CHANGELOG", "LICENSE", "README.md", "TODO", "lib/rails/generators/redis_orm/model/model_generator.rb", "lib/rails/generators/redis_orm/model/templates/model.rb.erb", "lib/redis_orm.rb", "lib/redis_orm/active_model_behavior.rb", "lib/redis_orm/associations/belongs_to.rb", "lib/redis_orm/associations/has_many.rb", "lib/redis_orm/associations/has_many_helper.rb", "lib/redis_orm/associations/has_many_proxy.rb", "lib/redis_orm/associations/has_one.rb", "lib/redis_orm/redis_orm.rb", "lib/redis_orm/utils.rb"]
  s.files = ["CHANGELOG", "Gemfile", "LICENSE", "Manifest", "README.md", "Rakefile", "TODO", "benchmarks/sortable_benchmark.rb", "lib/rails/generators/redis_orm/model/model_generator.rb", "lib/rails/generators/redis_orm/model/templates/model.rb.erb", "lib/redis_orm.rb", "lib/redis_orm/active_model_behavior.rb", "lib/redis_orm/associations/belongs_to.rb", "lib/redis_orm/associations/has_many.rb", "lib/redis_orm/associations/has_many_helper.rb", "lib/redis_orm/associations/has_many_proxy.rb", "lib/redis_orm/associations/has_one.rb", "lib/redis_orm/redis_orm.rb", "lib/redis_orm/utils.rb", "redis_orm.gemspec", "spec/generators/model_generator_spec.rb", "spec/spec_helper.rb", "test/association_indices_test.rb", "test/associations_test.rb", "test/atomicity_test.rb", "test/basic_functionality_test.rb", "test/callbacks_test.rb", "test/changes_array_test.rb", "test/classes/album.rb", "test/classes/article.rb", "test/classes/article_with_comments.rb", "test/classes/book.rb", "test/classes/catalog_item.rb", "test/classes/category.rb", "test/classes/city.rb", "test/classes/comment.rb", "test/classes/country.rb", "test/classes/custom_user.rb", "test/classes/cutout.rb", "test/classes/cutout_aggregator.rb", "test/classes/default_user.rb", "test/classes/dynamic_finder_user.rb", "test/classes/empty_person.rb", "test/classes/expire_user.rb", "test/classes/expire_user_with_predicate.rb", "test/classes/giftcard.rb", "test/classes/jigsaw.rb", "test/classes/location.rb", "test/classes/message.rb", "test/classes/note.rb", "test/classes/omni_user.rb", "test/classes/person.rb", "test/classes/photo.rb", "test/classes/profile.rb", "test/classes/sortable_user.rb", "test/classes/timestamp.rb", "test/classes/user.rb", "test/classes/uuid_default_user.rb", "test/classes/uuid_timestamp.rb", "test/classes/uuid_user.rb", "test/dynamic_finders_test.rb", "test/exceptions_test.rb", "test/expire_records_test.rb", "test/has_one_has_many_test.rb", "test/indices_test.rb", "test/modules/belongs_to_model_within_module.rb", "test/modules/has_many_model_within_module.rb", "test/options_test.rb", "test/polymorphic_test.rb", "test/redis.conf", "test/sortable_test.rb", "test/test_helper.rb", "test/uuid_as_id_test.rb", "test/validations_test.rb"]
  s.homepage = "https://github.com/german/redis_orm"
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Redis_orm", "--main", "README.md"]
  s.require_paths = ["lib"]
  s.rubyforge_project = "redis_orm"
  s.rubygems_version = "1.8.25"
  s.summary = "ORM for Redis (advanced key-value storage) with ActiveRecord API"
  s.test_files = ["test/association_indices_test.rb", "test/associations_test.rb", "test/atomicity_test.rb", "test/basic_functionality_test.rb", "test/callbacks_test.rb", "test/changes_array_test.rb", "test/dynamic_finders_test.rb", "test/exceptions_test.rb", "test/expire_records_test.rb", "test/has_one_has_many_test.rb", "test/indices_test.rb", "test/options_test.rb", "test/polymorphic_test.rb", "test/sortable_test.rb", "test/test_helper.rb", "test/uuid_as_id_test.rb", "test/validations_test.rb"]

  s.add_runtime_dependency(%q<activesupport>, [">= 5.1"])
  s.add_runtime_dependency(%q<activemodel>, [">= 5.1"])
  s.add_runtime_dependency(%q<redis>, [">= 4.2.5"])
  s.add_runtime_dependency(%q<uuid>, [">= 2.3.2"])
  s.add_development_dependency(%q<rspec>, [">= 3.10"])
  s.add_development_dependency(%q<rspec-rails>, [">= 3.0"])
  s.add_development_dependency(%q<ammeter>)
end
