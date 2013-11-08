module RedisOrm
  module Associations
    module HasManyHelper
      private  
      def save_index_for_associated_record(index, record, inception)
        prepared_index = if index[:name].is_a?(Array) # TODO sort alphabetically
          index[:name].inject(inception) do |sum, index_part|
            sum += [index_part, record.send(index_part.to_sym)]
          end.join(':')
        else
          inception += [index[:name], record.send(index[:name].to_sym)]
          inception.join(':')
        end

        prepared_index.downcase! if index[:options][:case_insensitive]

        if index[:options][:unique]
          RedisOrm.redis.set(prepared_index, record.id)
        else
          RedisOrm.redis.zadd(prepared_index, Time.now.to_f, record.id)
        end
      end
    end
  end
end
