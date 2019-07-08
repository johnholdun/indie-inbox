class HandleIncomingItem
  def initialize(activity, actor_id)
    @activity = activity
    @actor_id = actor_id
  end

  def call
    result =
      case activity['type']
      when 'Follow'
        _object_id =
          if activity['object'].is_a?(String)
            activity['object']
          else
            activity['object']['id']
          end
        if _object_id == actor_id
          FetchAccount.call(activity['actor'])
          follower_id = DB[:actors].where(uri: activity['actor']).first[:id]
          params = { actor: follower_id, object: actor_id }
          existing = DB[:follows].where(params)
          if existing.count.zero?
            DB[:follows].insert(params.merge(accepted: true))
          end
          actor_uri = DB[:actors].where(id: actor_id).first[:uri]
          FollowAccepter.call(actor_uri: actor_uri, activity: activity)
        end
      when 'Accept'
        FetchAccount.call(object['actor'])
        followed_id = DB[:actors].where(uri: object['actor']).first[:id]
        DB[:follows]
          .where(actor_id: actor_id, object_id: followed_id)
          .update(accepted: true)
      when 'Undo'
        if object['type'] == 'Follow' && object['object'] == actor_id
          DB[:follows].where(actor: object['actor'], object: actor_id).delete
        end
      end

    puts "Handled incoming activity\n#{actor_id}\n#{activity['id']}\n#{result.inspect}"
  end

  def self.call(*args)
    new(*args).call
  end

  private

  attr_reader :actor_id, :activity

  def object_or_id(obj)
    obj.is_a?(String) ? obj : obj['id']
  end

  def object
    @object ||=
      if activity['object'].is_a?(Hash)
        activity['object']
      else
        Request
          .new(
            :get,
            activity['object'],
            headers: { 'Accept' => 'application/activity+json, application/ld+json' }
          )
          .perform do |response|
            return Oj.load(response, mode: :strict) if response.code == 200
          end
      end
  end
end
