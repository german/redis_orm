module RedisOrm
  module Associations
    module HasMany
      # user.avatars => user:1:avatars => [1, 22, 234] => Avatar.find([1, 22, 234])
      # options
      #   *:dependant* key: either *destroy* or *nullify* (default)
      def has_many(foreign_models, options = {})
        class_associations = class_variable_get(:"@@associations")
        class_associations[model_name.singular] << {:type => :has_many, :foreign_models => foreign_models, :options => options}

        foreign_models_name = options[:as] ? options[:as].to_sym : foreign_models.to_sym

        define_method foreign_models_name.to_sym do
          Associations::HasManyProxy.new(model_name.singular, id, foreign_models, options)
        end

        # user = User.find(1)
        # user.avatars = Avatar.find(23) => user:1:avatars => [23]
        define_method "#{foreign_models_name}=" do |records|
          if !options[:as]
            # clear old assocs from related models side
            old_records = self.send(foreign_models).to_a
            if !old_records.empty?
              # cache here which association with current model have old record's model
              has_many_assoc = old_records[0].get_associations.detect do |h|
                h[:type] == :has_many && h[:foreign_models] == model_name.plural.to_sym
              end
              
              has_one_or_belongs_to_assoc = old_records[0].get_associations.detect do |h|
                [:has_one, :belongs_to].include?(h[:type]) && h[:foreign_model] == model_name.singular.to_sym
              end
              
              # delete ONLY associations (not any REAL models)
              old_records.each do |record|
                if has_many_assoc
                  $redis.zrem "#{record.model_name.singular}:#{record.id}:#{model_name.plural}", id
                elsif has_one_or_belongs_to_assoc
                  $redis.del "#{record.model_name.singular}:#{record.id}:#{model_name.singular}"
                end
              end
            end

            # clear old assocs from this model side
            $redis.zremrangebyscore "#{model_name.singular}:#{id}:#{foreign_models_name}", 0, Time.now.to_f
          end

          records.to_a.each do |record|
            # we use here *foreign_models_name* not *record.model_name.pluralize* because of the :as option
            key = "#{model_name.singular}:#{id}:#{foreign_models_name}"
            $redis.zadd(key, Time.now.to_f, record.id)
            set_expire_on_reference_key(key)
            
            record.get_indices.each do |index|
              # record.model_name.pluralize => foreign_models_name
              # TODO record.save_index
              save_index_for_associated_record(index, record, [model_name, id, record.model_name.plural])
            end

            # article.comments = [comment1, comment2] 
            # iterate through the array of comments and create backlink
            # check whether *record* object has *has_many* declaration and it states *self.model_name* in plural
            if assoc = class_associations[record.model_name.singular].detect{|h| h[:type] == :has_many && h[:foreign_models] == record.model_name.plural.to_sym} #&& !$redis.zrank("#{record.model_name}:#{record.id}:#{model_name.pluralize}", id)#record.model_name.to_s.camelize.constantize.find(id).nil?
              key = "#{record.model_name.singular}:#{record.id}:#{model_name.singular}"
              $redis.zadd(key, Time.now.to_f, id) if !$redis.zrank(key, id)
              set_expire_on_reference_key(key)
            end
              
            # check whether *record* object has *has_one* declaration and it states *self.model_name*
            if assoc = record.get_associations.detect{|h| [:has_one, :belongs_to].include?(h[:type]) && h[:foreign_model] == model_name.singular.to_sym}
              foreign_model_name = assoc[:options][:as] ? assoc[:options][:as] : model_name.singular
              key = "#{record.model_name.singular}:#{record.id}:#{foreign_model_name}"
              
              # overwrite assoc anyway so we don't need to check record.send(model_name.to_sym).nil? here
              $redis.set(key, id)              
              set_expire_on_reference_key(key)
            end
          end
        end
      end
    end
  end
end
