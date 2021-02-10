module RedisOrm
  module Associations
    module HasManyHelper
      private  
      def save_index_for_associated_record(index, record, index_prefix)
        index_name = if index.name.is_a?(Array) # TODO sort alphabetically
          index.name.inject(index_prefix) do |sum, index_part|
            sum += [index_part, record.public_send(index_part.to_sym)]
          end.join(':')
        else
          index_prefix += [index.name, record.public_send(index.name.to_sym)]
          index_prefix.join(':')
        end

        index_name.downcase! if index.options[:case_insensitive]

        if index.options[:unique]
          $redis.set(index_name, record.id)
        else
          $redis.zadd(index_name, Time.now.to_f, record.id)
        end
      end
    end
  end
end
