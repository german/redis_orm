# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{redis_orm}
  s.version = "0.4.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = [%q{Dmitrii Samoilov}]
  s.date = %q{2011-06-25}
  s.description = %q{ORM for Redis advanced key-value storage}
  s.email = %q{germaninthetown@gmail.com}
  s.extra_rdoc_files = [%q{CHANGELOG}, %q{LICENSE}, %q{README.md}, %q{lib/redis_orm.rb}, %q{lib/redis_orm/active_model_behavior.rb}, %q{lib/redis_orm/associations/belongs_to.rb}, %q{lib/redis_orm/associations/has_many.rb}, %q{lib/redis_orm/associations/has_many_proxy.rb}, %q{lib/redis_orm/associations/has_one.rb}, %q{lib/redis_orm/redis_orm.rb}]
  s.files = [%q{CHANGELOG}, %q{LICENSE}, %q{Manifest}, %q{README.md}, %q{Rakefile}, %q{lib/redis_orm.rb}, %q{lib/redis_orm/active_model_behavior.rb}, %q{lib/redis_orm/associations/belongs_to.rb}, %q{lib/redis_orm/associations/has_many.rb}, %q{lib/redis_orm/associations/has_many_proxy.rb}, %q{lib/redis_orm/associations/has_one.rb}, %q{lib/redis_orm/redis_orm.rb}, %q{redis_orm.gemspec}, %q{test/associations_test.rb}, %q{test/atomicity_test.rb}, %q{test/basic_functionality_test.rb}, %q{test/callbacks_test.rb}, %q{test/changes_array_test.rb}, %q{test/dynamic_finders_test.rb}, %q{test/exceptions_test.rb}, %q{test/has_one_has_many_test.rb}, %q{test/indices_test.rb}, %q{test/options_test.rb}, %q{test/polymorphic_test.rb}, %q{test/redis.conf}, %q{test/test_helper.rb}, %q{test/validations_test.rb}]
  s.homepage = %q{https://github.com/german/redis_orm}
  s.rdoc_options = [%q{--line-numbers}, %q{--inline-source}, %q{--title}, %q{Redis_orm}, %q{--main}, %q{README.md}]
  s.require_paths = [%q{lib}]
  s.rubyforge_project = %q{redis_orm}
  s.rubygems_version = %q{1.8.5}
  s.summary = %q{ORM for Redis advanced key-value storage}
  s.test_files = [%q{test/options_test.rb}, %q{test/dynamic_finders_test.rb}, %q{test/associations_test.rb}, %q{test/validations_test.rb}, %q{test/test_helper.rb}, %q{test/polymorphic_test.rb}, %q{test/atomicity_test.rb}, %q{test/exceptions_test.rb}, %q{test/has_one_has_many_test.rb}, %q{test/indices_test.rb}, %q{test/changes_array_test.rb}, %q{test/callbacks_test.rb}, %q{test/basic_functionality_test.rb}]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activesupport>, [">= 3.0.0"])
      s.add_runtime_dependency(%q<activemodel>, [">= 3.0.0"])
      s.add_runtime_dependency(%q<redis>, [">= 2.2.0"])
      s.add_development_dependency(%q<rspec>, [">= 2.5.0"])
    else
      s.add_dependency(%q<activesupport>, [">= 3.0.0"])
      s.add_dependency(%q<activemodel>, [">= 3.0.0"])
      s.add_dependency(%q<redis>, [">= 2.2.0"])
      s.add_dependency(%q<rspec>, [">= 2.5.0"])
    end
  else
    s.add_dependency(%q<activesupport>, [">= 3.0.0"])
    s.add_dependency(%q<activemodel>, [">= 3.0.0"])
    s.add_dependency(%q<redis>, [">= 2.2.0"])
    s.add_dependency(%q<rspec>, [">= 2.5.0"])
  end
end
