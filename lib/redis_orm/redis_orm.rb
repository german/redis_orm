require 'active_support/inflector/inflections'
require 'active_support/inflector/transliterate'
require 'active_support/inflector/methods'
require 'active_support/inflections'
require 'active_support/core_ext/string/inflections'

module RedisOrm
  module Associations
    class HasMany
      def initialize(reciever_model_name, reciever_id, records)
        @records = records.to_a
        @reciever_model_name = reciever_model_name
        @reciever_id = reciever_id
      end

      def [](index)
        @records[index]
      end

      # user = User.find(1)
      # user.avatars << Avatar.find(23) => user:1:avatars => [23]
      def <<(new_records)
        new_records.to_a.each do |record|
          #puts 'record - ' + record.inspect
          $redis.sadd("#{@reciever_model_name}:#{@reciever_id}:#{record.model_name.pluralize}", record.id)
          #puts "smembers #{@reciever_model_name}:#{@reciever_id}:#{record.model_name.pluralize} - " + $redis.smembers("#{@reciever_model_name}:#{@reciever_id}:#{record.model_name.pluralize}").inspect

          #puts 'record.get_associations ' + record.get_associations.inspect
          # article.comments << [comment1, comment2] 
          # iterate through the array of comments and create backlink
          # check whether *record* object has *has_many* declaration and TODO it states *self.model_name* in plural and there is no record yet from the *record*'s side (in order not to provoke recursion)
          #puts 'record.get_associations.detect{|h| h[:type] == :has_many && h[:foreign_models] == model_name.pluralize.to_sym} - '+record.get_associations.detect{|h| h[:type] == :has_many && h[:foreign_models] == @reciever_model_name.pluralize.to_sym}.inspect
          #puts 'record.model_name.to_s.capitalize.constantize.find(@reciever_id) - ' + record.model_name.to_s.capitalize.constantize.find(@reciever_id).inspect
          if record.get_associations.detect{|h| h[:type] == :has_many && h[:foreign_models] == @reciever_model_name.pluralize.to_sym} && record.model_name.to_s.capitalize.constantize.find(@reciever_id).nil?
            # raw
            # $redis.sadd("#{@reciever_model_name}:#{@reciever_id}:#{record.model_name.pluralize}", record.id)
            # or mode DRY
            #record.send(@reciever_model_name.pluralize.to_sym).send(:"<<", self)
            $redis.sadd("#{record.model_name}:#{record.id}:#{@reciever_model_name}", @reciever_id)

            #puts 'record.model_name - ' + record.model_name.inspect
            #puts '@@associations[record.model_name] ' + @@associations[record.model_name].inspect
            #puts 'record.send(model_name.pluralize.to_sym) - ' + record.send(model_name.pluralize.to_sym).inspect

          # check whether *record* object has *has_one* declaration and TODO it states *self.model_name* and there is no record yet from the *record*'s side (in order not to provoke recursion)
          elsif record.get_associations.detect{|h| [:has_one, :belongs_to].include?(h[:type]) && h[:foreign_model] == @reciever_model_name.to_sym} && record.send(@reciever_model_name.to_sym).nil?

            #puts 'record.model_name - ' + record.model_name.inspect
            #puts '@@associations[record.model_name] ' + @@associations[record.model_name].inspect
            #puts 'record.send(model_name.to_sym) - ' + record.send(model_name.to_sym).inspect
            $redis.set("#{record.model_name}:#{record.id}:#{@reciever_model_name}", @reciever_id)
            #record.send("#{@reciever_model_name}=", self)            
          end
        end
      end

      def method_missing(method_name, *args, &block)
        @records.send(method_name, *args, &block)        
      end
    end
=begin
    class BelongsTo
      def initialize(reciever_model_name, reciever_id, record)
        @record = record
        @reciever_model_name = reciever_model_name
        @reciever_id = reciever_id

        self.define_method @record.model_name.downcase do
          @record
        end
      end
    end
=end
  end

  class Base
    include ActiveModelBehavior

    attr_accessor :persisted

    @@properties = Hash.new{|h,k| h[k] = []}
    @@indices = Hash.new{|h,k| h[k] = []} # compound indices are available too   
    @@associations = Hash.new{|h,k| h[k] = []}
    @@callbacks = Hash.new{|h,k| h[k] = {}}    

    class << self

      def inherited(from)
        @@callbacks[from.model_name][:after_save] = []
        @@callbacks[from.model_name][:before_save] = []
        @@callbacks[from.model_name][:after_destroy] = []
        @@callbacks[from.model_name][:before_destroy] = []
      end
     
      def index(name)
        @@indices[model_name] << name
      end

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
        @@associations[model_name] << {:type => :belongs_to, :foreign_model => foreign_model, :options => options}

        define_method foreign_model.to_sym do
          foreign_model.to_s.capitalize.constantize.find($redis.get "#{model_name}:#{@id}:#{foreign_model}")
          #Associations::BelongsTo.new(model_name, id, records)
        end

        # look = Look.create :title => 'test'
        # look.user = User.find(1) => look:23:user => 1
        define_method "#{foreign_model}=" do |assoc_with_record|
          $redis.set("#{model_name}:#{id}:#{assoc_with_record.model_name}", assoc_with_record.id)

puts "@@associations[assoc_with_record.model_name].detect{|h| h[:type] == :has_many && h[:foreign_models] == model_name.pluralize.to_sym} - " + @@associations[assoc_with_record.model_name].detect{|h| h[:type] == :has_many && h[:foreign_models] == model_name.pluralize.to_sym}.inspect
puts '$redis.sismember("#{assoc_with_record.model_name}:#{assoc_with_record.id}:#{model_name.pluralize}", self.id) - ' + $redis.sismember("#{assoc_with_record.model_name}:#{assoc_with_record.id}:#{model_name.pluralize}", self.id).inspect

          # check whether *assoc_with_record* object has *has_many* declaration and TODO it states *self.model_name* in plural and there is no record yet from the *assoc_with_record*'s side (in order not to provoke recursion)
          if @@associations[assoc_with_record.model_name].detect{|h| h[:type] == :has_many && h[:foreign_models] == model_name.pluralize.to_sym} && !$redis.sismember("#{assoc_with_record.model_name}:#{assoc_with_record.id}:#{model_name.pluralize}", self.id)
            # raw
            # $redis.sadd("#{@reciever_model_name}:#{@reciever_id}:#{record.model_name.pluralize}", record.id)
            # or mode DRY
            assoc_with_record.send(model_name.pluralize.to_sym).send(:"<<", self)

puts 'assoc_with_record.model_name - ' + assoc_with_record.model_name.inspect
puts '@@associations[assoc_with_record.model_name] ' + @@associations[assoc_with_record.model_name].inspect
puts 'assoc_with_record.send(model_name.pluralize.to_sym) - ' + assoc_with_record.send(model_name.pluralize.to_sym).inspect

          # check whether *assoc_with_record* object has *has_one* declaration and TODO it states *self.model_name* and there is no record yet from the *assoc_with_record*'s side (in order not to provoke recursion)
          elsif @@associations[assoc_with_record.model_name].detect{|h| h[:type] == :has_one && h[:foreign_model] == model_name.to_sym} && assoc_with_record.send(model_name.to_sym).nil?

puts 'assoc_with_record.model_name - ' + assoc_with_record.model_name.inspect
puts '@@associations[assoc_with_record.model_name] ' + @@associations[assoc_with_record.model_name].inspect
puts 'assoc_with_record.send(model_name.to_sym) - ' + assoc_with_record.send(model_name.to_sym).inspect

            assoc_with_record.send("#{model_name}=", self)            
          end
        end
      end

      # user.avatars => user:1:avatars => [1, 22, 234] => Avatar.find([1, 22, 234])
      def has_many(foreign_models, options = {})
        @@associations[model_name] << {:type => :has_many, :foreign_models => foreign_models, :options => options}

        define_method foreign_models.to_sym do
          records = foreign_models.to_s.singularize.capitalize.constantize.find($redis.smembers "#{model_name}:#{@id}:#{foreign_models}")
          Associations::HasMany.new(model_name, id, records)
        end
      end

      # user.avatars => user:1:avatars => [1, 22, 234] => Avatar.find([1, 22, 234])
      # *options* is a hash and can hold:
      #   *:as* key
      #   *:dependant* key [:destroy, :nullify]
      def has_one(foreign_model, options = {})
        @@associations[model_name] << {:type => :has_one, :foreign_model => foreign_model, :options => options}

        foreign_model_name = if options[:as]
          options[:as].to_sym
        else
          foreign_model.to_sym
        end

        define_method foreign_model_name do
          foreign_model.to_s.capitalize.constantize.find($redis.get "#{model_name}:#{@id}:#{foreign_model}")
        end     

        # profile = Profile.create :title => 'test'
        # user.profile = profile => user:23:profile => 1
        define_method "#{foreign_model_name}=" do |assoc_with_record|
          $redis.set("#{model_name}:#{id}:#{assoc_with_record.model_name}", assoc_with_record.id)

puts 'assoc_with_record.model_name - ' + assoc_with_record.model_name.inspect
puts '@@associations[assoc_with_record.model_name] ' + @@associations[assoc_with_record.model_name].inspect
puts 'assoc_with_record.send(model_name.to_sym) - ' + assoc_with_record.send(model_name.to_sym).inspect

          # check whether *assoc_with_record* object has *belongs_to* declaration and TODO it states *self.model_name* and there is no record yet from the *assoc_with_record*'s side (in order not to provoke recursion)
          if @@associations[assoc_with_record.model_name].detect{|h| h[:type] == :belongs_to && h[:foreign_model] == model_name.to_sym} && assoc_with_record.send(model_name.to_sym).nil?
            assoc_with_record.send("#{model_name}=", self)            
          end
        end
      end

      def property(property_name, class_name)
        @@properties[model_name] << property_name

        send(:define_method, property_name) do
          instance_variable_get(:"@#{property_name}")
        end

        send(:define_method, :"#{property_name}=") do |value|
          instance_variable_set(:"@#{property_name}", value)
        end
      end

      def count
        $redis.zcard("#{model_name}:ids").to_i
      end

      def all(options = nil)
        if options && options.is_a?(Hash)
          if options[:limit]
            # ZREVRANGEBYSCORE album:ids 1305451611 1305443260 LIMIT 0, 2
            $redis.zrevrangebyscore("#{model_name}:ids", 0, -1, )
          end
          #prepared_index = options.to_a.sort{|n,m| n[0] <=> m[0]}.inject([model_name]) do |sum, option|
          #  sum += [option[0], option[1]]
          #end.join(':')
          #[$redis.get(prepared_index)].compact.collect{|id| find(id)}
        else
          $redis.zrange("#{model_name}:ids", 0, -1).compact.collect{|id| find(id)} # TODO add conditions
        end
      end

      def find(ids)
        if(ids.is_a?(Array))
          ids.inject([]) do |array, id|
            record = $redis.hgetall "#{model_name}:#{id}"
            if record && !record.empty?
              array << new(id, record, true)
            end
          end
        else
          id = ids
          record = $redis.hgetall "#{model_name}:#{id}"
          if record && record.empty?
            nil
          else
            new(id, record, true)
          end
        end        
      end

      def after_save(callback)        
        @@callbacks[model_name][:after_save] << callback
      end

      def before_destroy(callback)        
        @@callbacks[model_name][:before_destroy] << callback
      end

      def create(options = {})
        obj = new
        options.each do |key, value|
          obj.send(:key, value) if obj.respond_to?(:key)
        end
      end
    end

    # could be invoked from has_many module (<< method)
    def to_a
      [self]
    end

    # is called from RedisOrm::Associations::HasMany to save backlinks to saved records
    def get_associations
      @@associations[self.model_name]
    end

    def initialize(id = nil, hash = nil, persisted = false)
      @persisted = persisted
      
      instance_variable_set(:"@id", id.to_i) if id

      if hash && hash.is_a?(Hash)
        @@properties[model_name].each do |prop|          
          instance_variable_set(:"@#{prop}", hash[prop.to_s]) if hash[prop.to_s]
        end
      end
      self
    end

    def id
      @id
    end

    def persisted?
      @persisted
    end

    def save
      if !persisted?
        @id = $redis.incr("#{model_name}:id")
        $redis.zadd "#{model_name}:ids", Time.now.to_i, @id
        @persisted = true
      end

      @@callbacks[model_name][:before_save].each do |callback|
        self.send(callback)
      end

      @@properties[model_name].each do |prop|
        #puts 'self.send(prop.to_sym) - ' + self.send(prop.to_sym).to_s
        $redis.hset("#{model_name}:#{id}", prop.to_s, self.send(prop.to_sym))
      end

      # TODO make correct indices
      # save indices in order to sort by finders
      @@indices[model_name].each do |index|
        if index.is_a?(Array) # TODO sort alphabetically
          prepared_index = index.inject([model_name]) do |sum, index_part|
            sum += [index_part, self.instance_variable_get(:"@#{index_part}")]
          end.join(':')
          $redis.set(prepared_index, @id)
        else
          prepared_index = [model_name, index, self.instance_variable_get(:"@#{index}")].join(':')
          $redis.set(prepared_index, @id)        
        end
      end

      @@callbacks[model_name][:after_save].each do |callback|
        self.send(callback)
      end
    end

    def update_attributes(attributes)
      if attributes.is_a?(Hash)
        #@@properties[model_name].each do |prop|          
        #  instance_variable_set(:"@#{prop}", attributes[prop.to_s]) if attributes[prop.to_s]
        #end
        attributes.each do |key, value|
          self.send("#{key}=".to_sym, value) if self.respond_to?("#{key}=".to_sym)
        end
      end
    end

    def destroy
      @@callbacks[model_name][:before_destroy].each do |callback|
        self.send(callback)
      end

      # also we need to delete associations
      if !@@associations[model_name].empty?
        @@associations[model_name].each do |assoc|

          foreign_model  = ""
          records = []

          case assoc[:type]
            when :belongs_to
              foreign_model = assoc[:foreign_model].to_s
              foreign_model_name = assoc[:options][:as] ? assoc[:options][:as] : assoc[:foreign_model]
              records << self.send(foreign_model_name)

              $redis.del "#{model_name}:#{@id}:#{assoc[:foreign_model]}"
            when :has_one
              foreign_model = assoc[:foreign_model].to_s
              foreign_model_name = assoc[:options][:as] ? assoc[:options][:as] : assoc[:foreign_model]
              records << self.send(foreign_model_name)

              puts "TODO"
            when :has_many
              foreign_model = assoc[:foreign_models].to_s.singularize
              foreign_models_name = assoc[:options][:as] ? assoc[:options][:as] : assoc[:foreign_models]
              records = self.send(foreign_models_name)

              # there is no command to delete the set so just empty it
              $redis.scard("#{model_name}:#{@id}:#{assoc[:foreign_models]}").to_i.times do
                $redis.spop "#{model_name}:#{@id}:#{assoc[:foreign_models]}"
              end
          end

puts 'from destroy foreign_model - ' + foreign_model.inspect
puts 'from destroy records - ' + records.inspect
puts 'from destroy records.compact.empty? - ' + records.compact.empty?.inspect

          # check whether foreign_model also has an assoc to the destroying record
          # and remove an id of destroing record from each of associated sets
          if !records.compact.empty?
            records.compact.each do |record|
              if @@associations[foreign_model].detect{|h| h[:type] == :belongs_to && h[:foreign_model] == model_name.to_sym}
                puts 'from destr :belongs_to - ' + "#{foreign_model}:#{record.id}:#{model_name}"
                $redis.del "#{foreign_model}:#{record.id}:#{model_name}"
              elsif @@associations[foreign_model].detect{|h| h[:type] == :has_one && h[:foreign_model] == model_name.to_sym}
                puts 'from destr :has_one - ' + "#{foreign_model}:#{record.id}:#{model_name}"
                $redis.del "#{foreign_model}:#{record.id}:#{model_name}"
              elsif @@associations[foreign_model].detect{|h| h[:type] == :has_many && h[:foreign_models] == model_name.pluralize.to_sym}
                puts "from destr :has_many - " + "#{foreign_model}:#{record.id}:#{model_name.pluralize}"
                $redis.srem "#{foreign_model}:#{record.id}:#{model_name.pluralize}", @id
              end
            end
          end
        end
      end

      @@properties[model_name].each do |prop|
        $redis.hdel("#{model_name}:#{@id}", prop.to_s)
      end

      $redis.zrem "#{model_name}:ids", @id

      # we need to ensure that smembers are correct after removal of the record
      @@indices[model_name].each do |index|
        if index.is_a?(Array) # TODO sort alphabetically
          prepared_index = index.inject([model_name]) do |sum, index_part|
            sum += [index_part, self.instance_variable_get(:"@#{index_part}")]
          end.join(':')
          $redis.del(prepared_index)
        else
          prepared_index = [model_name, index, self.instance_variable_get(:"@#{index}")].join(':')
          $redis.del(prepared_index)
        end
      end
      
      @@callbacks[model_name][:after_destroy].each do |callback|
        self.send(callback)
      end
    end    
  end
end
