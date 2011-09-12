# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{redis_orm}
  s.version = "0.6"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["Dmitrii Samoilov"]
  s.date = %q{2011-09-12}
  s.description = %q{ORM for Redis (advanced key-value storage) with ActiveRecord API}
  s.email = %q{germaninthetown@gmail.com}
  s.extra_rdoc_files = ["CHANGELOG", "LICENSE", "README.md", "lib/redis_orm.rb", "lib/redis_orm/active_model_behavior.rb", "lib/redis_orm/associations/belongs_to.rb", "lib/redis_orm/associations/has_many.rb", "lib/redis_orm/associations/has_many_helper.rb", "lib/redis_orm/associations/has_many_proxy.rb", "lib/redis_orm/associations/has_one.rb", "lib/redis_orm/redis_orm.rb", "lib/redis_orm/utils.rb"]
  s.files = ["CHANGELOG", "LICENSE", "Manifest", "README.md", "Rakefile", "lib/redis_orm.rb", "lib/redis_orm/active_model_behavior.rb", "lib/redis_orm/associations/belongs_to.rb", "lib/redis_orm/associations/has_many.rb", "lib/redis_orm/associations/has_many_helper.rb", "lib/redis_orm/associations/has_many_proxy.rb", "lib/redis_orm/associations/has_one.rb", "lib/redis_orm/redis_orm.rb", "lib/redis_orm/utils.rb", "redis_orm.gemspec", "test/association_indices_test.rb", "test/associations_test.rb", "test/atomicity_test.rb", "test/basic_functionality_test.rb", "test/callbacks_test.rb", "test/changes_array_test.rb", "test/dynamic_finders_test.rb", "test/exceptions_test.rb", "test/has_one_has_many_test.rb", "test/indices_test.rb", "test/options_test.rb", "test/order_test.rb", "test/polymorphic_test.rb", "test/redis.conf", "test/test_helper.rb", "test/uuid_as_id_test.rb", "test/validations_test.rb"]
  s.homepage = %q{https://github.com/german/redis_orm}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Redis_orm", "--main", "README.md"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{redis_orm}
  s.rubygems_version = %q{1.6.2}
  s.summary = %q{ORM for Redis (advanced key-value storage) with ActiveRecord API}
  s.test_files = ["test/options_test.rb", "test/dynamic_finders_test.rb", "test/associations_test.rb", "test/validations_test.rb", "test/test_helper.rb", "test/polymorphic_test.rb", "test/uuid_as_id_test.rb", "test/atomicity_test.rb", "test/exceptions_test.rb", "test/association_indices_test.rb", "test/has_one_has_many_test.rb", "test/order_test.rb", "test/indices_test.rb", "test/changes_array_test.rb", "test/callbacks_test.rb", "test/basic_functionality_test.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>, [">= 3.0.0"])
      s.add_runtime_dependency(%q<activemodel>, [">= 3.0.0"])
      s.add_runtime_dependency(%q<redis>, [">= 2.2.0"])
      s.add_runtime_dependency(%q<uuid>, [">= 2.3.2"])
      s.add_development_dependency(%q<rspec>, [">= 2.5.0"])
    else
      s.add_dependency(%q<activesupport>, [">= 3.0.0"])
      s.add_dependency(%q<activemodel>, [">= 3.0.0"])
      s.add_dependency(%q<redis>, [">= 2.2.0"])
      s.add_dependency(%q<uuid>, [">= 2.3.2"])
      s.add_dependency(%q<rspec>, [">= 2.5.0"])
    end
  else
    s.add_dependency(%q<activesupport>, [">= 3.0.0"])
    s.add_dependency(%q<activemodel>, [">= 3.0.0"])
    s.add_dependency(%q<redis>, [">= 2.2.0"])
    s.add_dependency(%q<uuid>, [">= 2.3.2"])
    s.add_dependency(%q<rspec>, [">= 2.5.0"])
  end
end
