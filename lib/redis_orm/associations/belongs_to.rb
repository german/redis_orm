module RedisOrm
  module Associations
    module BelongsTo
      # class Avatar < RedisOrm::Base
      #   belongs_to :user
      # end 
      #
      # class User < RedisOrm::Base
      #   has_many :avatars
      # end 
      #
      # avatar.user => avatar:234:user => 1 => User.find(1)
      def belongs_to(foreign_model, options = {})
        class_associations = class_variable_get(:"@@associations")
        belongs_to_hash = {
          type: :belongs_to,
          foreign_model: foreign_model,
          options: options
        }
        class_variable_get(:"@@associations")[model_name.singular] << belongs_to_hash

        foreign_model_name = options[:as] ? options[:as].to_sym : foreign_model.to_sym
        
        if options[:index]
          index = Index.new(foreign_model_name, {reference: true})
          class_variable_get(:"@@indices")[model_name.singular] << index
        end
        
        define_method foreign_model_name do
          __key__ = "#{model_name.singular}:#{@id}:#{foreign_model_name}"

          if options[:polymorphic]
            model_type = $redis.get("#{model_name.singular}:#{id}:#{foreign_model_name}_type")
            if model_type
              model_type.to_s.camelize.constantize.find($redis.get "#{__key__}_id")
            end
          else
            # find model even if it's in some module
            full_model_scope = RedisOrm::Base.descendants.detect{|desc| desc.to_s.split('::').include?(foreign_model.to_s.camelize) }
            if full_model_scope
              full_model_scope.find($redis.get __key__)
            else
              foreign_model.to_s.camelize.constantize.find($redis.get __key__)
            end
          end
        end
  
        # look = Look.create :title => 'test'
        # look.user = User.find(1) => look:23:user => 1
        define_method "#{foreign_model_name}=" do |assoc_with_record|
          # we need to store this to clear old association later
          old_assoc = self.send(foreign_model_name)
          __key__ = "#{model_name.singular}:#{id}:#{foreign_model_name}"

          # find model even if it's in some module
          full_model_scope = RedisOrm::Base.descendants.detect do |desc|
            desc.to_s.split('::').include?(foreign_model.to_s.camelize)
          end

          if options[:polymorphic]
            $redis.set("#{__key__}_type", assoc_with_record.model_name.singular)
            $redis.set("#{__key__}_id", assoc_with_record.id)
          else
            if assoc_with_record.nil?
              $redis.del(__key__)
            elsif [foreign_model.to_s, full_model_scope.model_name.singular].include?(assoc_with_record.model_name.singular)
              $redis.set(__key__, assoc_with_record.id)
            else
              raise TypeMismatchError
            end
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
          
          # we should have an option to delete created earlier associasion (like 'node.owner = nil')
          if assoc_with_record.nil?
            # remove old assoc            
            $redis.zrem("#{old_assoc.model_name.singular}:#{old_assoc.id}:#{model_name.plural}", self.id) if old_assoc
          else
            # check whether *assoc_with_record* object has *has_many* declaration and
            # TODO it states *self.model_name* in plural 
            # and there is no record yet from the *assoc_with_record*'s side 
            # (in order not to provoke recursion)
            if class_associations[assoc_with_record.model_name.singular].detect{|h| h[:type] == :has_many && h[:foreign_models] == model_name.plural.to_sym} && !$redis.zrank("#{assoc_with_record.model_name.singular}:#{assoc_with_record.id}:#{model_name.plural}", self.id)
              # remove old assoc
              $redis.zrem("#{old_assoc.model_name.singular}:#{old_assoc.id}:#{model_name.plural}", self.id) if old_assoc
              assoc_with_record.send(model_name.plural.to_sym).send(:"<<", self)

            # check whether *assoc_with_record* object has *has_one* declaration and TODO it states *self.model_name* and there is no record yet from the *assoc_with_record*'s side (in order not to provoke recursion)
            elsif class_associations[assoc_with_record.model_name.singular].detect{|h| h[:type] == :has_one && h[:foreign_model] == model_name.singular.to_sym} && assoc_with_record.send(model_name.singular.to_sym).nil?
              # old association is being rewritten here automatically so we don't have to worry about it
              assoc_with_record.send("#{model_name.singular}=", self)
            end
          end
        end
      end
    end
  end
end
