module RedisOrm
  module Associations
    module HasOne
      # user.avatars => user:1:avatars => [1, 22, 234] => Avatar.find([1, 22, 234])
      # *options* is a hash and can hold:
      #   *:as* key
      #   *:dependant* key: either *destroy* or *nullify* (default)
      def has_one(foreign_model, options = {})
        class_associations = class_variable_get(:"@@associations")
        class_associations[model_name.singular] << {
          type: :has_one,
          foreign_model: foreign_model,
          options: options
        }

        foreign_model_name = if options[:as]
          options[:as].to_sym
        else
          foreign_model.to_sym
        end

        if options[:index]
          index = Index.new(foreign_model_name, {reference: true})
          class_variable_get(:"@@indices")[model_name.singular] << index
        end
        
        define_method foreign_model_name do
          foreign_model.to_s.camelize.constantize.find($redis.get "#{model_name.singular}:#{@id}:#{foreign_model_name}")
        end     

        # profile = Profile.create :title => 'test'
        # user.profile = profile => user:23:profile => 1
        define_method "#{foreign_model_name}=" do |assoc_with_record|
          # we need to store this to clear old associations later
          old_assoc = self.send(foreign_model_name)

          reference_key = "#{model_name.singular}:#{id}:#{foreign_model_name}"

          if assoc_with_record.nil?
            $redis.del(reference_key)
          elsif assoc_with_record.model_name.singular == foreign_model.to_s
            $redis.set(reference_key, assoc_with_record.id)
            set_expire_on_reference_key(reference_key)
          else
            raise TypeMismatchError
          end
          
          # handle indices for references
          self.get_indices.select{|index| index.options[:reference]}.each do |index|
            # delete old reference that points to the old associated record
            if !old_assoc.nil?
              prepared_index = [model_name.singular, index.name, old_assoc.id].join(':')
              prepared_index.downcase! if index.options[:case_insensitive]

              if index.options[:unique]
                $redis.del(prepared_index, id)
              else
                $redis.zrem(prepared_index, id)
              end
            end
            
            # if new associated record is nil then skip to next index (since old associated record was already unreferenced)
            next if assoc_with_record.nil?
            
            prepared_index = [model_name.singular, index.name, assoc_with_record.id].join(':')

            prepared_index.downcase! if index.options[:case_insensitive]

            if index.options[:unique]
              $redis.set(prepared_index, id)
            else
              $redis.zadd(prepared_index, Time.now.to_f, id)
            end
          end

          if !options[:as]
            if assoc_with_record.nil?
              # remove old assoc
              $redis.zrem("#{old_assoc.model_name.singular}:#{old_assoc.id}:#{model_name.plural}", id) if old_assoc
            else
              # check whether *assoc_with_record* object has *belongs_to* declaration and TODO it states *self.model_name* and there is no record yet from the *assoc_with_record*'s side (in order not to provoke recursion)
              assoc_with_record_has_belongs_to_deslaration = class_associations[assoc_with_record.model_name.singular].detect{|h| [:belongs_to, :has_one].include?(h[:type]) && h[:foreign_model] == model_name.singular.to_sym} && assoc_with_record.send(model_name.singular.to_sym).nil?

              if assoc_with_record_has_belongs_to_deslaration
                # old association is being rewritten here automatically so we don't have to worry about it
                assoc_with_record.send("#{model_name.singular}=", self)
              elsif class_associations[assoc_with_record.model_name.singular].detect{|h| :has_many == h[:type] && h[:foreign_models] == model_name.plural.to_sym} && !$redis.zrank("#{assoc_with_record.model_name.singular}:#{assoc_with_record.id}:#{model_name.plural}", self.id)
                # remove old assoc
                $redis.zrem("#{old_assoc.model_name.singular}:#{old_assoc.id}:#{model_name.plural}", id) if old_assoc

                # create/add new ones
                assoc_with_record.send(model_name.plural.to_sym).send(:"<<", self)
              end
            end
          end
        end
      end
    end
  end
end
